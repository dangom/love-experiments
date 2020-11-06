-----------------------------------------------------------------------------
-- Run a flickering checkerboard visual experiment

-- Author: Daniel Gomez
-- Date: 10.31.2020
-----------------------------------------------------------------------------
local os = require("os")
local math = require("math")
local string = require("string")

local love = require("love")

local logger = require("tools.log") -- my logging utilities
local mathutils = require("tools.mathutils") -- my aux math functions
local patterns = require("visual.patterns") -- generate flicker checkerboard
local lume = require("lib.lume") -- for serializing data into a string
local json = require("lib.JSON") -- for serializing data into json

-- Forward declare experimental variables
local window = {} -- Window configuration, height and width
local task = {} -- Task experimental setup variables
local canvas = {} -- The off-screen canvas with the images to be drawn to screen
local state = {} -- Current state of the task
local dot = {} -- Control the center dot
local events = {} -- A variable for logging events.
-- Add a header to the recorded events.
events[1] = {"onset", "duration"," sample", "trial_type", "response_time", "value"}

local reactions = {} -- A table of reactions to each dot change in the experiment
local reaction_times = {} -- A table with reaction times.
local results = {} -- Store the hitrate and the average reaction time.

local function save_data(data, task_info)
   -- Save a serialized easy to reload data.
   local serialized = lume.serialize(data)
   local csv = logger.to_csv(data)

   local out_dir = task_info.SUB_ID .. "/"
   love.filesystem.createDirectory(out_dir)
   local out_name = task_info.RUN_ID .. "_"

   -- Also save the run info (csv for human readable format)
   love.filesystem.write(out_dir .. out_name .. "log.txt", serialized)
   love.filesystem.write(out_dir .. out_name .. "events.csv", csv)
   love.filesystem.write(
      out_dir .. out_name .. "runtime-info.json",
      json:encode_pretty(logger.runtime_info())
   )
   love.filesystem.write(
      out_dir .. out_name .. "stimulus-info.json",
      json:encode_pretty(task_info)
   )
   print("Files were saved to" .. love.filesystem.getAppdataDirectory() .. "/" .. out_dir .. out_name .. "*")

end


function love.load(arg)
   -- Seed the random generator.
   math.randomseed(os.time())

   -- Assume we want to show checkerboard onto full FOV, and no resize allowed.
   window.WIDTH, window.HEIGHT = love.graphics.getDimensions()

   -- user set variables
   task.SUB_ID = arg[1] or "DEBUG-sub-id"
   task.RUN_ID = arg[2] or "DEBUG-run-id"

   task.FREQUENCY = tonumber(arg[3]) or 0.1 -- Hz
   task.EXPONENT = tonumber(arg[4]) or 1 -- The exponent of the oscillation.
   task.LUMINANCE = tonumber(arg[5]) or 0.8
   task.IS_OSCILLATION = arg[6] and true or false

   -- Task timing
   task.timing = {}
   task.timing.OFFSET = tonumber(arg[7]) or 2
   task.timing.TOTAL_DURATION = tonumber(arg[8]) or 10
   task.timing.RESULTS_DISPLAY_DURATION = 4
   task.ACQUISITION_DATE = os.date()

   -- Configuration of checkerboard taken from Jingyuan's matlab experiments
   task.RADIAL_SPACING = 6 -- radial spacing
   task.CONCENTRIC_SPACING = 10 -- concentric spacing
   task.FLICKER_FREQUENCY = tonumber(arg[9]) or 12 -- flickering in Hz.
   -- Configuration of the dot
   task.dot = {}
   task.dot.SIZE = 10
   -- The maximum reaction time for computing a "hit"
   task.MAX_REACTION_TIME = 0.6 -- seconds

   print(
      string.format("Setup: Frequency=%.2f Hz, Exponent=%d, Luminance=%.2f %%, Flicker=%d Hz",
      task.FREQUENCY, task.EXPONENT, 100*task.LUMINANCE, task.FLICKER_FREQUENCY
   ))
   print("Is the stimulus a sinusoidal?", task.IS_OSCILLATION)
   print(
      string.format("Timing: Offset=%d s, TotalDuration=%.2f s",
      task.timing.OFFSET, task.timing.TOTAL_DURATION
   ))

   -- Create the checkerboard pattern
   local CHECKS = patterns.checkerboard(
      window.WIDTH, window.HEIGHT, task.RADIAL_SPACING, task.CONCENTRIC_SPACING
   )
   canvas = {}
   --render_to_texture(pattern, color_LUT)
   canvas[0] = patterns.render_to_texture(CHECKS, {{0, 0, 0},{1, 1, 1}})
   canvas[1] = patterns.render_to_texture(CHECKS, {{1, 1, 1},{0, 0, 0}})

   -- Initialize stateful variables.
   state.is_running = false -- Whether the actual task has started (not waiting for trigger)
   state.is_finished = false -- Whether the task has finished (displaying the results)

   state.time = 0 -- The experimental clock in seconds. Kicks off after the trigger is received.
   state.flicker_time = 0   -- this keeps track of how much time has passed in flicker cycles
   state.modulation_time = - task.timing.OFFSET * task.FREQUENCY -- this keeps track of how much the oscillation has evolved
   state.phase = 0 -- the phase of the stimulus
   state.alpha = 0 -- the instantaneous stimulus intensity
   state.trigger_count = -1 -- The number of triggers received
   state.results_display_time_left = task.timing.RESULTS_DISPLAY_DURATION

   state.keypress = {} -- keeps the timestamp of last keypress for logging keypress durations
   state.keypress.onset = {}
   state.keypress.reaction_time = {}

   -- The dot clock
   dot.clock = 0
   -- The time it takes for an initial dot color change (uniform rand from 0.8 to 3s)
   dot.current_isi = mathutils.random_float(0.8, 3)
   -- Whether the dot is active
   dot.is_active = true
   dot.color = {0.5, 0, 0}
   dot.draw_pressed = false

   -- The background color, which should eventually depend on the target luminance.
   love.graphics.setBackgroundColor(0.5, 0.5, 0.5)
   love.mouse.setVisible(false)
   love.graphics.setFont(love.graphics.newFont(30))

end


function love.update(dt)
   -- Hold off the stateful clocks until we receive the first trigger.
   if not state.is_running then
      return
   end

   -- Advance clock.
   state.time = state.time + dt
   -- Advance flicker normalized by flicker rate (change independent of FPS)
   state.flicker_time = state.flicker_time + task.FLICKER_FREQUENCY * dt
   -- Advance modulation clock
   state.modulation_time = state.modulation_time + task.FREQUENCY * dt
   -- Advance dot reaction time clock
   dot.clock = dot.clock + dt

   if dot.clock > dot.current_isi then
      dot.clock = dot.clock - dot.current_isi -- Reset the clock and loop for new ISI
      if not state.is_finished then
         love.event.push(
            "log", state.time, dot.current_isi, state.trigger_count, "DOT_FLIP", "N/A", dot.is_active and 1 or 0
         )
      end
      dot.current_isi = mathutils.random_float(0.8, 3)
      if dot.is_active then dot.color = {0.8, 0, 0} else dot.color = {0.5, 0, 0} end
      dot.is_active = not dot.is_active
      reactions[#reactions + 1] = "N/A" -- This will be overwritten by 0 if late or 1 if response
   end

   -- State changes if experiment comes to an end
   if state.time > task.timing.TOTAL_DURATION then
      -- This goes inside of this check because we don't want to update the hitrate after the task finishes.
      if not state.is_finished then
         results.hitrate = 100 * mathutils.sum(reactions) / #reactions
         results.avg_rt = mathutils.sum(reaction_times) / #reaction_times

         print(string.format("Hit Rate = %.2f %%", results.hitrate))
         print(string.format("Average Reaction Time = %.2f seconds", results.avg_rt))

         love.event.push(
            "log", state.time, 0, state.trigger_count, "FINISH", "N/A", string.format("%.2f %%", results.hitrate)
         )
      end
      if not state.is_finished then
         print("Task finished at: " .. os.date())
      end
      state.is_finished = true
      state.results_display_time_left = state.results_display_time_left - dt
   end
end


function love.draw()
   -- The hold means that we are waiting for a trigger, so we don't start the experiment.
   if not state.is_running then
      love.graphics.setColor(0.6, 0, 0)
      love.graphics.printf("The task will begin shortly...", 0, 2*window.HEIGHT/5, window.WIDTH, 'center')
      -- Draw the dot
      love.graphics.setColor(dot.color)
      love.graphics.circle("fill", window.WIDTH/2, window.HEIGHT/2, task.dot.SIZE)
      return
   end

   if not state.is_finished then
      -- This means experiment started, but we are waiting for a steady state.
      if state.time < task.timing.OFFSET then
         state.phase = math.pi
         state.alpha = 0
      else
         local alpha_offset = 1 -- So that alpha ranges from 0 to 2, instead of -1 to 1.
         local alpha_normalization = 2 -- So that alpha ranges from 0 to 1, instead of 0 to 2.
         state.phase = (state.modulation_time + 0.5) % 1 * 2 * math.pi
         if task.IS_OSCILLATION then
            state.alpha = ((math.cos(state.phase)+alpha_offset)/alpha_normalization)^task.EXPONENT * task.LUMINANCE
         else -- ON/OFF at given frequency
            state.alpha = state.phase >= math.pi and task.LUMINANCE or 0
         end
      end

      love.graphics.setColor(1, 1, 1, state.alpha)
      -- Draw the texture
      love.graphics.setBlendMode("alpha")
      love.graphics.draw(canvas[math.floor(state.flicker_time) % 2])

      -- Draw the dot
      love.graphics.setColor(dot.color)
      love.graphics.circle("fill", window.WIDTH/2, window.HEIGHT/2, task.dot.SIZE)

      -- Debug clocks
      -- if true then
      --    love.graphics.setColor(0.7, 0, 0)
      --    love.graphics.printf(state.time, 0, window.HEIGHT/5, window.WIDTH, 'center')
      --    love.graphics.printf(state.modulation_time, 0, 2*window.HEIGHT/5, window.WIDTH, 'center')
      -- end

      if dot.draw_pressed then
         if reactions[#reactions] == 1 then
            love.graphics.setColor(0,1,0)
         else
            love.graphics.setColor(1,0,0)
         end
         love.graphics.circle("line", window.WIDTH/2, window.HEIGHT/2, task.dot.SIZE)
      end

   -- If the experiment has finished, show the average reaction time and the hit rate.
   else
      local hitrate_str = string.format("Hit Rate = %.2f %%", results.hitrate)
      local avg_rt_str = string.format("Average Reaction Time = %.2f seconds", results.avg_rt)

      love.graphics.setColor(0.6,0,0)

      love.graphics.printf("Your task results:", 0, 2*window.HEIGHT/5 - 30, window.WIDTH, 'center')
      love.graphics.printf(hitrate_str, 0, 2*window.HEIGHT/5 + 20, window.WIDTH, 'center')
      love.graphics.printf(avg_rt_str, 0, 2*window.HEIGHT/5 + 70, window.WIDTH, 'center')

      if state.results_display_time_left < 0 then
         save_data(events, task)
         love.event.quit()
      end
   end
end


function love.handlers.log(onset, duration, sample, trial_type, response_time, value)
   events[#events + 1] = {onset, duration, sample, trial_type, response_time, value}
end


-- Handle keypresses.
function love.keypressed(key, scancode)
   if key == "escape" then
      -- Don't push it to the async event logger because we will save and quit immediately.
      events[#events + 1] = {state.time, 0, state.trigger_count, "CANCELLED", "n/a", "n/a"}
      save_data(events, task)
      print("The run was cancelled after ", state.time, " seconds.")
      love.event.quit()
   end

   -- Received trigger
   if key == "=" then
      state.trigger_count = state.trigger_count + 1
      love.event.push(
         "log", state.time, 0, state.trigger_count, "TRIGGER", state.phase, math.floor(state.modulation_time + 0.5)
      )
      state.is_running = true

      if state.trigger_count == 0 then
         print("Task started at: " .. os.date())
      end
   end

   -- Received keypress
   if key == "1" or key == "2" or key == "3" or key == "4" or key == "5" then

      state.keypress.onset[key] = state.time
      state.keypress.reaction_time[key] = dot.clock

      reaction_times[#reaction_times + 1] = dot.clock
      -- 1 if clock < max reaction time, 0 otherwise
      reactions[#reactions] = dot.clock < task.MAX_REACTION_TIME and 1 or 0

      dot.draw_pressed = true
   end
end


function love.keyreleased(key, scancode)
   if key == "1" or key == "2" or key == "3" or key == "4" or key == "5" then
      local duration = state.time - state.keypress.onset[key]
      love.event.push(
         "log",
         state.keypress.onset[key],
         duration,
         state.trigger_count,
         "KEYPRESS",
         state.keypress.reaction_time[key],
         key
      )

      dot.draw_pressed = false
   end
end
