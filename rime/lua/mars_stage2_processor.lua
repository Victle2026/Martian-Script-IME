local generator = require("mars_candidates")

local kAccepted = 1
local kNoop = 2
local STAGE_INPUT = "~m"

local function candidate_for_key(context, key_repr, page_size)
  if not context:has_menu() then
    return nil
  end
  local segment = context.composition:back()
  if not segment then
    return nil
  end

  if key_repr == "space" or key_repr == "Return" then
    return segment:get_selected_candidate(), segment.selected_index, segment
  end

  local digit = string.match(key_repr, "^([1-9])$")
  if not digit then
    digit = string.match(key_repr, "^KP_([1-9])$")
  end
  if not digit then
    return nil, nil, segment
  end

  local offset = tonumber(digit) - 1
  if offset >= page_size then
    return nil, nil, segment
  end
  local page_start = math.floor(segment.selected_index / page_size) * page_size
  local candidate_index = page_start + offset
  return segment:get_candidate_at(candidate_index), candidate_index, segment
end

local function enter_stage_two(context, source, raw_input, sequence)
  local seed = generator.hash(
    table.concat({ os.time(), os.clock(), sequence, raw_input, source }, ":")
  )
  context:clear()
  context:set_property("mars_stage", "2")
  context:set_property("mars_source", source)
  context:set_property("mars_raw_input", raw_input)
  context:set_property("mars_seed", tostring(seed))
  context:push_input(STAGE_INPUT)
end

local processor = {}

function processor.init(env)
  env.sequence = 0
  env.page_size = env.engine.schema.config:get_int("menu/page_size") or 7
end

function processor.func(key, env)
  if key:release() or key:ctrl() or key:alt() or key:super() then
    return kNoop
  end
  local context = env.engine.context
  if context:get_option("ascii_mode") or not context:get_option("mars_two_stage") then
    return kNoop
  end

  local stage = context:get_property("mars_stage")
  local key_repr = key:repr()
  if stage == "2" and context.input == STAGE_INPUT then
    if key_repr == "Escape" or key_repr == "BackSpace" then
      local raw_input = context:get_property("mars_raw_input")
      context:clear()
      context:set_property("mars_stage", "")
      if raw_input and raw_input ~= "" then
        context:push_input(raw_input)
      end
      return kAccepted
    end
    return kNoop
  end

  local candidate, candidate_index, segment = candidate_for_key(
    context,
    key_repr,
    env.page_size
  )
  if not candidate then
    return kNoop
  end

  local candidate_end = candidate._end or segment._end
  if candidate_end < #context.input then
    return kNoop
  end

  if candidate_index ~= segment.selected_index then
    context:select(candidate_index)
  end
  local source = context:get_commit_text()
  if not source or source == "" or string.match(source, "[A-Za-z]") then
    return kNoop
  end

  env.sequence = env.sequence + 1
  enter_stage_two(context, source, context.input, env.sequence)
  return kAccepted
end

return processor
