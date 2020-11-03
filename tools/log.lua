--[[
 For logging data in BIDS format, events are saved as following:
   ONSET, DURATION, SAMPLE, TRIAL_TYPE, RESPONSE_TIME, VALUE
   where
   ONSET - the time given in seconds from the first trigger (beginning of acquisition)
   DURATION - the duration of the event
   SAMPLE - in which volume TR the event happened.
   TRIAL_TYPE - categorisation of trial
   RESPONSE_TIME - the reaction time. N/A refers to no-response
   VALUE - which key was pressed
--]]

local log = {}

-- Capture output of command line command
local function os_capture(cmd, raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  if raw then return s end
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end

log.stimulus_info = function()
   local info = {}
   info["OperatingSystem"] = os_capture("uname")

   local major, minor, revision, codename = love.getVersion()
   local software_version = string.format("Version %d.%d.%d - %s", major, minor, revision, codename)

   info["SoftwareName"] = "LÖVE"
   info["SoftwareVersion"] = software_version
   info["Stimulus Frequency"] = oscillation_frequency
   info["Start Time"] = start_time

   return info
end

log.to_csv = function(t)
   local out = {}
   local s = tostring
   for k, r in pairs(t) do
      local rowstr = string.format("%s\t%s\t%s\t%s\t%s\t%s",
                                   s(r[1]), s(r[2]), s(r[3]), s(r[4]), s(r[5]), s(r[6]))
      out[#out+1] = rowstr
   end
   return table.concat(out, "\n")
end

return log
