-----------------------------------------------------------------------------
-- Run a flickering checkerboard visual experiment

-- Goals:
-- [X] Flicker at a given frequency regardless of FPS
-- [X] Modulate the intensity of the flickering (osc stimuli)
-- [X] Randomly flicker a red dot
-- [X] Log all keypresses and their time in milliseconds from start of experiment
-- [X] Exit on escape
-- [ ] Give feedback when experiment ends

-- Author: Daniel Gomez
-- Date: 10.31.2020

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
-----------------------------------------------------------------------------
require("checkerboard")

math.randomseed(os.clock()*100000000000)

-- Sum all elements of a table
function sum(t)
    local sum = 0
    for k,v in pairs(t) do
       if type(v) == "number" then
          sum = sum + v
       end
    end

    return sum
end

function csv_string(t)
   local out = {}
   local s = tostring
   for k, r in pairs(t) do
      local rowstr = string.format("%s\t%s\t%s\t%s\t%s\t%s",
                                   s(r[1]), s(r[2]), s(r[3]), s(r[4]), s(r[5]), s(r[6]))
      out[#out+1] = rowstr
   end
   return table.concat(out, "\n")
end

-- Capture output of command line command
function os.capture(cmd, raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  if raw then return s end
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end

local function software_info()
   info = {}
   info["OperatingSystem"] = os.capture("uname")

   local major, minor, revision, codename = love.getVersion()
   local software_version = string.format("Version %d.%d.%d - %s", major, minor, revision, codename)

   info["SoftwareName"] = "LÖVE"
   info["SoftwareVersion"] = software_version

   return info
end


-- Creates a canvas an renders an array to it.
-- Assumes that colorcode has 2 entries, one for 0 and one for 1.
local function render_to_texture(array, colorcode)
   -- Take that the array has the size of the screen.
   width = #array
   height = #array[1]
   canvas = love.graphics.newCanvas(width, height)
   love.graphics.setCanvas(canvas)
   love.graphics.clear()
   love.graphics.setBlendMode("alpha")
   -- Loop over the array and draw values into the canvas.
   for i,row in ipairs(array) do
      for j,tile in ipairs(row) do
         --First check if the tile is not zero
         love.graphics.setColor(colorcode[tile+1])
         --Draw the tile
         love.graphics.rectangle("fill", i, j, 1, 1)
      end
   end
   -- Reset canvas so that draw operations outside this function don't overwrite
   -- it
   love.graphics.setCanvas()
   return canvas
end

function love.load()
   -- Lume is a library with helper functions
   -- One of these allows serializing tables for saving.
   lume = require("lume")

   -- Assume we want to show checkerboard onto full FOV.
   width, height = love.graphics.getDimensions()

   -- Configuration of checkerboard taken from Jingyuan's matlab experime
   local sr = 6 -- radial spacing
   local sc = 10 -- concentric spacing
   -- Create the checkerboard pattern
   local checks = checkerboard(width, height, sr, sc)

   --Create a look up table for the values in the checkerboard.
   -- A reversed checkerboard is done by reverting the LUT.
   local lut_forward = {{1, 1, 1},{0, 0, 0}}
   local lut_backward = {{0, 0, 0},{1, 1, 1}}

   canvas_forward = render_to_texture(checks, lut_forward)
   canvas_backward = render_to_texture(checks, lut_backward)

   canvas = canvas_forward -- The initial canvas to be drawn to the screen.

   -- Initialize experimental variables.

   time = 0 -- The experimental clock in seconds. Kicks off after the trigger is received.
   trigger_count = -1 -- The number of triggers received
   flickerrate = 12 -- flickering per second.
   dtotal = 0   -- this keeps track of how much time has passed
   offset = 4 -- seconds before stimulus starts

   oscillation_frequency = 0.16 -- Hz
   contrast_exponent = 1 -- The exponent of the oscillation.
   luminance = 0.7

   -- The time it takes for an initial dot color change (uniform rand from 0.8 to 3s)
   dot_change = math.random(0.8, 3)
   -- The dot clock
   dot_clock = 0
   -- Whether the dot is active
   dot_on = true
   dot_color = {0.5, 0, 0}

   -- Maximum acceptable reaction time for color changing.
   maxrt = 0.6

   -- This is a dummy variable indicating that the experiment hasn't started.
   -- It signals that the trigger has not been received yet.
   hold = true

   -- The events that will be saved to the logfile.
   events = {}
   -- Add a header to the recorded events.
   events[1] = {"ONSET", "DURATION"," SAMPLE", "TRIAL_TYPE", "RESPONSE_TIME", "VALUE"}

   reactions = {}
   reaction_times = {}
   experiment_duration = 20
   experiment_finished = false
   wait_clock = 5

   -- The background color, which should eventually depend on the target luminance.
   gray = luminance / 2
   love.graphics.setBackgroundColor(gray, gray, gray)

end

function love.update(dt)

   if hold then
      return
   end

   -- This is the normalized change independent of FPS.
   local change = flickerrate * dt
   time = time + dt

    -- we add the time passed since the last update, probably a very small number like 0.01
   dtotal = dtotal + change
   if dtotal >= 1 then
      -- reduce our timer by a second, but don't discard the change... what if
      -- our framerate is 2/3 of a second?
      dtotal = dtotal - 1
      love.event.push("flicker")
   end

   -- Handle the dot
   dot_clock = dot_clock + dt
   if dot_clock > dot_change then
      dot_clock = dot_clock - dot_change
      dot_change = math.random(0.8, 3)
      love.event.push("flip_dot")
      reactions[#reactions + 1] = "N/A"
   end

   if time > experiment_duration then
      if not experiment_finished then
         hitrate = 100 * sum(reactions) / #reactions
         avg_rt = sum(reaction_times) / #reaction_times
      end
      experiment_finished = true
      wait_clock = wait_clock - dt
   end

end

function love.draw()

   -- The hold means that we are waiting for a trigger, so we don't start the experiment.
   if hold then
      -- Draw the dot
      love.graphics.setColor(dot_color)
      love.graphics.circle("fill", width/2, height/2, 10, 100)
      return
   end

   -- This means experiment started, but we are waiting for a steady state.
   if time < offset then
      alpha = 0
   else
      local phase = (time-offset-1/oscillation_frequency/4)*oscillation_frequency*math.pi*2
      local alpha_offset = 1 -- So that alpha ranges from 0 to 2, instead of -1 to 1.
      local alpha_normalization = 2 -- So that alpha ranges from 0 to 1, instead of 0 to 2.

      alpha=(((math.sin(phase)+alpha_offset)/alpha_normalization)^contrast_exponent) * luminance
   end

   -- very important!: reset color before drawing to canvas to have colors properly displayed
   -- see discussion here: https://love2d.org/forums/viewtopic.php?f=4&p=211418#p211418
   love.graphics.setColor(1, 1, 1, alpha)

   if not experiment_finished then
      -- Draw the texture
      love.graphics.setBlendMode("alpha")
      love.graphics.draw(canvas)

      -- Draw the dot
      love.graphics.setColor(dot_color)
      love.graphics.circle("fill", width/2, height/2, 10, 100)

   -- If the experiment has finished, show the average reaction time and the hit rate.
   else
      love.graphics.setBackgroundColor(1, 1, 1, 1)
      love.graphics.clear(1, 1, 1, 1)
      love.graphics.setColor(dot_color)
      love.graphics.print("Hit Rate: " .. tostring(hitrate) .. "%", width/2 - 40, height/2 - 10)
      love.graphics.print("Average RT: " .. tostring(avg_rt), width/2 - 40, height/2 + 20)
      if wait_clock < 0 then
         save_data(events)
         love.event.quit()
      end
   end

end

-- Inverts the texture to be painted.
function love.handlers.flicker()
   if canvas == canvas_forward then
      canvas = canvas_backward
   else
      canvas = canvas_forward
   end
end

-- Updates the dot color.
function love.handlers.flip_dot()
   if dot_on then
      dot_color = {0.8, 0, 0}
      dot_on = false
   else
      dot_color = {0.5, 0, 0}
      dot_on = true
   end
end

function love.handlers.log(onset, duration, sample, trial_type, response_time, value)
   events[#events + 1] = {onset, duration, sample, trial_type, response_time, value}
end


function save_data(data)
   -- Save a serialized easy to reload data.
   serialized = lume.serialize(data)
   love.filesystem.write("savedata.txt", serialized)
   -- And save a human friendly version.
   csv = csv_string(data)
   love.filesystem.write("savedata.csv", csv)
end

-- Handle keypresses.
function love.keypressed(key, scancode, isrepeat)
   if key == "escape" then
      save_data(events)
      love.event.quit()
   end

   -- Received trigger
   if key == "=" then
      trigger_count = trigger_count + 1
      love.event.push("log", time, 0, trigger_count, "TRIGGER", "N/A", "N/A")
      hold = false
   end

   -- Received keypress
   if key == "1" or key == "2" or key == "3" or key == "4" then
      reaction_times[#reaction_times + 1] = dot_clock
      if dot_clock < maxrt then
         reactions[#reactions] = 1
         response = true
      else
         reactions[#reactions] = 0
         response = false
      end
      -- For now don't care about the duration of the keypress.
      love.event.push("log", time, 0, trigger_count, "KEYPRESS", dot_clock, key)
   end
end
