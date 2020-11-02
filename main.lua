-----------------------------------------------------------------------------
-- Run a flickering checkerboard visual experiment

-- Goals:
-- [X] Flicker at a given frequency regardless of FPS
-- [X] Modulate the intensity of the flickering (osc stimuli)
-- [X] Randomly flicker a red dot
-- [X] Log all keypresses and their time in milliseconds from start of experiment
-- [X] Exit on escape
-- [X] Give feedback when experiment ends

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
local logger = require("tools.log")
local mathutils = require("tools.mathutils")

-- Generate checkerboard and render to texture
local patterns = require("visual.patterns")
-- Lume is a library with helper functions
-- One of these allows serializing tables for saving.
local lume = require("lib.lume")

function save_data(data)
   -- Save a serialized easy to reload data.
   local serialized = lume.serialize(data)
   love.filesystem.write("savedata.txt", serialized)
   -- And save a human friendly version.
   local csv = logger.to_csv(data)
   love.filesystem.write("savedata.csv", csv)

   -- Also save the run info
   love.filesystem.write("stimulus-info.txt", lume.serialize(logger.stimulus_info()))
end

-- Forward declare experimental variables
local width, height
local oscillation_frequency, contrast_exponent, luminance
local canvas_forward, canvas_backward, canvas
local time, trigger_count, flickerrate, dtotal, offset
local dot_change, dot_clock, dot_on, dot_color
local hold, maxrt
local events, reactions, reaction_times

local experiment_duration, experiment_finished, wait_clock
local gray, flicker_state
local start_time
local twopifreq

function love.load(arg)

   math.randomseed(os.clock()*100000000000)

   -- user set variables
   oscillation_frequency = arg[1] or 0.1 -- Hz
   contrast_exponent = arg[2] or 1 -- The exponent of the oscillation.
   luminance = arg[3] or 0.8

   twopifreq = 2*math.pi*oscillation_frequency

   -- Assume we want to show checkerboard onto full FOV.
   width, height = love.graphics.getDimensions()

   -- Configuration of checkerboard taken from Jingyuan's matlab experiments
   local sr = 6 -- radial spacing
   local sc = 10 -- concentric spacing

   -- Create the checkerboard pattern
   local checks = patterns.checkerboard(width, height, sr, sc)

   --Create a look up table for the values in the checkerboard.
   -- A reversed checkerboard is done by reverting the LUT.
   local lut_forward = {{1, 1, 1},{0, 0, 0}}
   local lut_backward = {{0, 0, 0},{1, 1, 1}}

   canvas_forward = patterns.render_to_texture(checks, lut_forward)
   canvas_backward = patterns.render_to_texture(checks, lut_backward)

   canvas = canvas_forward -- The initial canvas to be drawn to the screen.

   -- Initialize experimental variables.

   time = 0 -- The experimental clock in seconds. Kicks off after the trigger is received.
   trigger_count = -1 -- The number of triggers received
   flickerrate = 12 -- flickering per second.
   dtotal = 0   -- this keeps track of how much time has passed

   offset = 2 -- seconds before stimulus starts

   -- The time it takes for an initial dot color change (uniform rand from 0.8 to 3s)
   dot_change = mathutils.random_float(0.8, 3)
   -- The dot clock
   dot_clock = 0
   -- Whether the dot is active
   dot_on = true
   dot_color = {0.5, 0, 0}

   -- Maximum acceptable reaction time for button press hit rate calc.
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
   experiment_duration = 10
   experiment_finished = false
   wait_clock = 8

   -- The background color, which should eventually depend on the target luminance.
   gray = 0.5
   love.graphics.setBackgroundColor(gray, gray, gray)
   love.mouse.setVisible(false)
   love.graphics.setFont(love.graphics.newFont(30))
   start_time = os.date()

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
      dot_change = mathutils.random_float(0.8, 3)
      love.event.push("flip_dot")
      reactions[#reactions + 1] = "N/A" -- This will be overwritten by 0 if late or 1 if response
   end

   -- State changes if experiment comes to an end
   if time > experiment_duration then
      if not experiment_finished then
         hitrate = 100 * mathutils.sum(reactions) / #reactions
         avg_rt = mathutils.sum(reaction_times) / #reaction_times
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
      local phase = (time-offset-1/oscillation_frequency/4)*twopifreq
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
      -- love.graphics.setBackgroundColor(1, 1, 1, 1)
      -- love.graphics.clear(1, 1, 1, 1)
      love.graphics.setColor(0.6,0,0)
      love.graphics.printf("Your task results:", 3*width/18, 2*height/5 - 30, 2*width/3, 'center')
      local hitrate_str = string.format("Hit Rate = %.2f %%", hitrate)
      love.graphics.printf(hitrate_str, 3*width/18, 2*height/5 + 20, 2*width/3, 'center')
      local avg_rt_str = string.format("Average Reaction Time = %.2f seconds", avg_rt)
      love.graphics.printf(avg_rt_str, 3*width/18, 2*height/5 + 70, 2*width/3, 'center')
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
