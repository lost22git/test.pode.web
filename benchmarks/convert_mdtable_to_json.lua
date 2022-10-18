-- trim string
local trim = function(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- json encode
-- copy from https://github.com/rxi/json.lua/blob/master/json.lua
local encode
local escape_char_map = {
  ["\\"] = "\\",
  ["\""] = "\"",
  ["\b"] = "b",
  ["\f"] = "f",
  ["\n"] = "n",
  ["\r"] = "r",
  ["\t"] = "t",
}

local function escape_char(c)
  return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end

local function encode_nil(val)
  return "null"
end

local function encode_table(val, stack)
  local res = {}
  stack = stack or {}

  -- Circular reference?
  if stack[val] then error("circular reference") end

  stack[val] = true

  if rawget(val, 1) ~= nil or next(val) == nil then
    -- Treat as array -- check keys are valid and it is not sparse
    local n = 0
    for k in pairs(val) do
      if type(k) ~= "number" then
        error("invalid table: mixed or invalid key types")
      end
      n = n + 1
    end
    if n ~= #val then
      error("invalid table: sparse array")
    end
    -- Encode
    for i, v in ipairs(val) do
      table.insert(res, encode(v, stack))
    end
    stack[val] = nil
    return "[" .. table.concat(res, ",") .. "]"

  else
    -- Treat as an object
    for k, v in pairs(val) do
      if type(k) ~= "string" then
        error("invalid table: mixed or invalid key types")
      end
      table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
    end
    stack[val] = nil
    return "{" .. table.concat(res, ",") .. "}"
  end
end

local function encode_string(val)
  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end

local function encode_number(val)
  -- Check for NaN, -inf and inf
  if val ~= val or val <= -math.huge or val >= math.huge then
    error("unexpected number value '" .. tostring(val) .. "'")
  end
  return string.format("%.14g", val)
end

local type_func_map = {
  ["nil"] = encode_nil,
  ["table"] = encode_table,
  ["string"] = encode_string,
  ["number"] = encode_number,
  ["boolean"] = tostring,
}

encode = function(val, stack)
  local t = type(val)
  local f = type_func_map[t]
  if f then
    return f(val, stack)
  end
  error("unexpected type '" .. t .. "'")
end


---------------------------------------------------------------------
---------------------------------------------------------------------

local src_path = arg[1]
local dest_path = arg[2]

-- Read src_path
local src_file = io.open(src_path, 'r')
assert(src_file, "Failed to open the source file: " .. src_path)
local dest_file = io.open(dest_path, 'w')
assert(dest_file, 'Failed to open the destination file: ' .. dest_path)

local header = {}
local body = {}
local match_char = '|'

local parse_line = function(line)
  local last_match_index = 0
  local header_line = #header == 0
  local row = {}
  local column_index = 0
  for i = 1, #line do
    local c = string.sub(line, i, i)
    if c == match_char then
      if last_match_index > 0 then
        column_index = column_index + 1
        local v = trim(string.sub(line, last_match_index + 1, i - 1))
        if header_line then -- header line found
          table.insert(header, v)
          --print('Get Header: ' .. v)
        else
          if string.find(v, '--', 1, true) then -- format line found
            -- print("Get format line")
            return
          else
            row[header[column_index]] = v
            --print('Get ' .. header[column_index] .. ' = ' .. v)
            if column_index == 1 then
              table.insert(body, row)
            end
          end
        end
      end
      last_match_index = i
    end
  end
end

while true do
  local line = src_file:read()
  if (line == nil) then
    break
  end
  -- Parse each line
  parse_line(line)
end

local json = encode(body)
dest_file:write(json)

dest_file:close()
src_file:close()
