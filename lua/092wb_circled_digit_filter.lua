local function should_yield(text, option)
  -- filter out the circled digit **if and only if**
  -- the option is off, cand.text length == 1 and the code belong to [①,⑨]
  if not option and utf8.len(text) == 1 then
    local code = utf8.codepoint(text)
    if code >= utf8.codepoint("①") and code <= utf8.codepoint("⑨") then
      return false
    end
  end
  return true
end

local function filter(input, env)
  local on = env.engine.context:get_option("circled_digit")
  for cand in input:iter() do
    if should_yield(cand.text, on) then
      yield(cand)
    end
  end
end

local function init(env)
  -- do nothing when init
end

return { init = init, func = filter }
