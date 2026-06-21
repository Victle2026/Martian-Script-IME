local generator = require("mars_candidates")

local STAGE_INPUT = "~m"
local VARIANT_COUNT = 6

local translator = {}

function translator.func(input, segment, env)
  if input ~= STAGE_INPUT then
    return
  end
  local context = env.engine.context
  if context:get_property("mars_stage") ~= "2" then
    return
  end
  local source = context:get_property("mars_source")
  if not source or source == "" then
    return
  end
  local seed = tonumber(context:get_property("mars_seed")) or generator.hash(source)
  local variants = generator.generate(source, context, seed, VARIANT_COUNT)

  for _, variant in ipairs(variants) do
    local candidate = Candidate(
      "mars_stage2",
      segment.start,
      segment._end,
      variant.text,
      generator.comment(variant)
    )
    candidate.preedit = "火星文：" .. source
    yield(candidate)
  end

  local original = Candidate(
    "mars_original",
    segment.start,
    segment._end,
    source,
    "〔原文〕"
  )
  original.preedit = "火星文：" .. source
  yield(original)
end

return translator
