local data = require("mars_methods_data")

local UINT32 = 4294967296

local function stable_hash(value)
  local hash = 2166136261
  value = tostring(value or "")
  for index = 1, #value do
    hash = (hash * 31 + string.byte(value, index)) % UINT32
  end
  return hash
end

local function create_random(seed)
  local state = stable_hash(seed)
  return function()
    state = (1664525 * state + 1013904223) % UINT32
    return state / UINT32
  end
end

local function copy_array(values)
  local result = {}
  for _, value in ipairs(values or {}) do
    result[#result + 1] = value
  end
  return result
end

local function add_method(methods, method)
  if not method then
    return
  end
  for _, existing in ipairs(methods) do
    if existing == method then
      return
    end
  end
  methods[#methods + 1] = method
end

local function weighted_pick(items, profile, random)
  if #items == 0 then
    return nil
  end
  local weights = {}
  local total = 0
  for index, item in ipairs(items) do
    local method_weight = profile.method_weights[item.method] or 0
    local weight = math.max(0, (item.weight or 1) * method_weight)
    weights[index] = weight
    total = total + weight
  end
  if total <= 0 then
    return items[math.floor(random() * #items) + 1]
  end
  local cursor = random() * total
  for index, item in ipairs(items) do
    cursor = cursor - weights[index]
    if cursor <= 0 then
      return item
    end
  end
  return items[#items]
end

local function eligible_variants(variants, enabled)
  local result = {}
  for _, variant in ipairs(variants or {}) do
    if enabled[variant.method] then
      result[#result + 1] = variant
    end
  end
  return result
end

local function pick_variant(variants, profile, enabled, random)
  return weighted_pick(eligible_variants(variants, enabled), profile, random)
end

local function pick_primary_variant(variants, profile, enabled)
  local best = nil
  local best_weight = -1
  for _, variant in ipairs(eligible_variants(variants, enabled)) do
    local method_weight = profile.method_weights[variant.method] or 0
    local weight = (variant.weight or 1) * method_weight
    if weight > best_weight then
      best = variant
      best_weight = weight
    end
  end
  return best
end

local function find_phrase(text, position, enabled)
  local best = nil
  local best_length = 0
  for _, rule in ipairs(data.phrase_rules) do
    local source_length = #rule.source
    if source_length > best_length and
       string.sub(text, position, position + source_length - 1) == rule.source and
       #eligible_variants(rule.variants, enabled) > 0 then
      best = rule
      best_length = source_length
    end
  end
  return best
end

local function next_character(text, position)
  local next_position = utf8.offset(text, 2, position)
  if not next_position then
    next_position = #text + 1
  end
  return string.sub(text, position, next_position - 1), next_position
end

local function render_base(
  text,
  profile,
  enabled,
  seed,
  force_first,
  phrase_mode,
  replace_rate
)
  local random = create_random(seed)
  local methods = {}
  local output = {}
  local transformed = false
  local position = 1

  while position <= #text do
    local consumed_phrase = false
    local phrase = nil
    if phrase_mode ~= "off" then
      phrase = find_phrase(text, position, enabled)
    end
    local use_phrase = phrase and (
      phrase_mode == "primary" or
      phrase_mode == "random" or
      random() < profile.phrase_rate or
      (force_first and not transformed)
    )
    if use_phrase then
      local variant = nil
      if phrase_mode == "primary" then
        variant = pick_primary_variant(phrase.variants, profile, enabled)
      else
        variant = pick_variant(phrase.variants, profile, enabled, random)
      end
      if variant then
        output[#output + 1] = variant.text
        add_method(methods, variant.method)
        transformed = transformed or variant.text ~= phrase.source
        position = position + #phrase.source
        consumed_phrase = true
      end
    end

    if not consumed_phrase then
      local char, next_position = next_character(text, position)
      local variants = data.char_rules[char] or {}
      local eligible = eligible_variants(variants, enabled)
      if #eligible > 0 and
         (random() < (replace_rate or profile.replace_rate) or
          (force_first and not transformed)) then
        local variant = nil
        if phrase_mode == "primary" then
          variant = pick_primary_variant(variants, profile, enabled)
        else
          variant = weighted_pick(eligible, profile, random)
        end
        if variant then
          output[#output + 1] = variant.text
          add_method(methods, variant.method)
          transformed = transformed or variant.text ~= char
        else
          output[#output + 1] = char
        end
      else
        output[#output + 1] = char
      end
      position = next_position
    end
  end

  return {
    text = table.concat(output),
    methods = methods,
    transformed = transformed,
  }
end

local function pick_decoration(items, profile, enabled, random)
  return weighted_pick(eligible_variants(items or {}, enabled), profile, random)
end

local function split_characters(text)
  local chars = {}
  for _, codepoint in utf8.codes(text) do
    chars[#chars + 1] = utf8.char(codepoint)
  end
  return chars
end

local function insert_separators(text, separator, count, random)
  local chars = split_characters(text)
  if #chars < 3 or count < 1 then
    return text
  end
  local positions = {}
  for position = 1, #chars - 1 do
    if not string.match(chars[position], "%s") and
       not string.match(chars[position + 1], "%s") then
      positions[#positions + 1] = position
    end
  end
  local selected = {}
  while #positions > 0 and #selected < count do
    local index = math.floor(random() * #positions) + 1
    selected[positions[index]] = true
    table.remove(positions, index)
  end
  local output = {}
  for index, char in ipairs(chars) do
    output[#output + 1] = char
    if selected[index] then
      output[#output + 1] = separator
    end
  end
  return table.concat(output)
end

local function decorate(result, profile_name, profile, enabled, seed)
  if result.text == "" or profile.decoration_rate <= 0 then
    return result
  end
  local random = create_random(tostring(seed) .. ":decoration")
  if random() >= profile.decoration_rate then
    return result
  end

  local actions = { "suffix", "separator", "frame" }
  local action_count = 1
  if profile_name == "wild_mix" and random() < 0.48 then
    action_count = 2
  end
  local text = result.text
  local methods = copy_array(result.methods)

  for _ = 1, action_count do
    if #actions == 0 then
      break
    end
    local action_index = math.floor(random() * #actions) + 1
    local action = table.remove(actions, action_index)
    if action == "suffix" then
      local suffix = pick_decoration(data.decorations.suffixes, profile, enabled, random)
      if suffix then
        text = text .. suffix.text
        add_method(methods, suffix.method)
      end
    elseif action == "separator" then
      local separator = pick_decoration(data.decorations.separators, profile, enabled, random)
      if separator then
        local maximum = math.max(1, profile.max_separators or 1)
        local count = math.floor(random() * maximum) + 1
        text = insert_separators(text, separator.text, count, random)
        add_method(methods, separator.method)
      end
    else
      local frame = pick_decoration(data.decorations.frames, profile, enabled, random)
      if frame then
        text = frame.left .. text .. frame.right
        add_method(methods, frame.method)
      end
    end
  end

  return {
    text = text,
    methods = methods,
    transformed = result.transformed or text ~= result.text,
  }
end

local function generate_detailed(
  text,
  profile_name,
  enabled,
  seed,
  phrase_mode,
  replace_rate
)
  local profile = data.profiles[profile_name]
  local result = render_base(
    text,
    profile,
    enabled,
    seed,
    false,
    phrase_mode,
    replace_rate
  )
  if not result.transformed then
    result = render_base(
      text,
      profile,
      enabled,
      tostring(seed) .. ":forced",
      true,
      phrase_mode,
      replace_rate
    )
  end
  if phrase_mode == "primary" then
    return result
  end
  return decorate(result, profile_name, profile, enabled, seed)
end

local function generate_choices(text, enabled, batch_seed, count)
  local plans = {
    {
      profile = "classic_mix",
      phrase_mode = "primary",
      role = "phrase_primary",
      homophone_only = true,
      replace_rate = 1.0,
    },
    {
      profile = "classic_mix",
      phrase_mode = "random",
      role = "phrase_variant",
      homophone_only = true,
      replace_rate = 0.82,
    },
    { profile = "classic_mix", phrase_mode = "off", role = "classic_free" },
    { profile = "wild_mix", phrase_mode = "off", role = "wild_free" },
    { profile = "wild_mix", phrase_mode = "off", role = "wild_free" },
    { profile = "wild_mix", phrase_mode = "off", role = "wild_free" },
  }
  local seen = { [text] = true }
  local results = {}

  for candidate_index = 1, count do
    local plan = plans[((candidate_index - 1) % #plans) + 1]
    local profile_name = plan.profile
    local plan_enabled = enabled
    if plan.homophone_only then
      plan_enabled = { homophone = enabled.homophone }
    end
    local fallback = nil
    for attempt = 0, 31 do
      local seed = stable_hash(
        table.concat({ batch_seed, candidate_index, attempt, profile_name, text }, ":")
      )
      local candidate = generate_detailed(
        text,
        profile_name,
        plan_enabled,
        seed,
        plan.phrase_mode,
        plan.replace_rate
      )
      if not fallback or candidate.text ~= text then
        fallback = candidate
      end
      if candidate.text ~= text and not seen[candidate.text] then
        candidate.profile = profile_name
        candidate.role = plan.role
        results[#results + 1] = candidate
        seen[candidate.text] = true
        fallback = nil
        break
      end
    end
    if fallback and fallback.text ~= text and not seen[fallback.text] then
      fallback.profile = profile_name
      fallback.role = plan.role
      results[#results + 1] = fallback
      seen[fallback.text] = true
    end
  end
  return results
end

local function has_han(text)
  local ok, found = pcall(function()
    for _, codepoint in utf8.codes(text) do
      if (codepoint >= 0x3400 and codepoint <= 0x9fff) or
         (codepoint >= 0xf900 and codepoint <= 0xfaff) or
         (codepoint >= 0x20000 and codepoint <= 0x3134f) then
        return true
      end
    end
    return false
  end)
  return ok and found
end

local function enabled_methods(context)
  local enabled = {}
  for method, _ in pairs(data.method_labels) do
    enabled[method] = true
  end
  if not context:get_option("mars_cross_script") then
    enabled.zhuyin = false
    enabled.kana = false
    enabled.hangul = false
  end
  if not context:get_option("mars_symbols") then
    enabled.symbol = false
  end
  return enabled
end

local function method_comment(candidate)
  local labels = {}
  for _, method in ipairs(candidate.methods) do
    labels[#labels + 1] = data.method_labels[method] or method
  end
  local profile = "异星"
  if candidate.role == "phrase_primary" then
    profile = "经典词"
  elseif candidate.role == "phrase_variant" then
    profile = "词组变体"
  elseif candidate.profile == "classic_mix" then
    profile = "经典"
  end
  if #labels == 0 then
    return "〔" .. profile .. "〕"
  end
  return "〔" .. profile .. " · " .. table.concat(labels, "/") .. "〕"
end

local mars_candidates = {}

function mars_candidates.generate(text, context, batch_seed, count)
  if not has_han(text) then
    return {}
  end
  return generate_choices(
    text,
    enabled_methods(context),
    batch_seed,
    count or 6
  )
end

function mars_candidates.comment(candidate)
  return method_comment(candidate)
end

function mars_candidates.hash(value)
  return stable_hash(value)
end

-- Compatibility for an already-built V3 schema during the short window before
-- Weasel is redeployed. The V4 schema only uses this module as a generator.
function mars_candidates.init(env)
  env.compatibility_seed = stable_hash(tostring(os.time()) .. ":" .. tostring(os.clock()))
end

function mars_candidates.func(input, env)
  local context = env.engine.context
  for candidate in input:iter() do
    yield(candidate)
    if context:get_option("mars_v3") and has_han(candidate.text) then
      local variants = mars_candidates.generate(
        candidate.text,
        context,
        stable_hash(env.compatibility_seed .. ":" .. context.input .. ":" .. candidate.text),
        2
      )
      for _, variant in ipairs(variants) do
        yield(ShadowCandidate(
          candidate,
          "mars_v3",
          variant.text,
          method_comment(variant)
        ))
      end
    end
  end
end

return mars_candidates
