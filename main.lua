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
local toboolean = require('lib.toboolean')

-- Forward declare experimental variables
local window = {} -- Window configuration, height and width
local task = {} -- Task experimental setup variables
local canvas = {} -- The off-screen canvas with the images to be drawn to screen
local state = {} -- Current state of the task
local dot = {} -- Control the center dot
local events = {} -- A variable for logging events.
-- Add a header to the recorded events.
events[1] = {
    "onset", "duration", " sample", "trial_type", "response_time", "value"
}

local reactions = {} -- A table of reactions to each dot change in the experiment
local reaction_times = {} -- A table with reaction times.
local results = {} -- Store the hitrate and the average reaction time.
-- local debug_start = {} -- debug clock start time
-- local debug_end = {} -- debug clock end time

-- For scalednoise
local scalednoise = {}
local scalednoise_rev = {}

local function save_data(data, task_info)
    -- Save a serialized easy to reload data.
    local serialized = lume.serialize(data)
    local csv = logger.to_csv(data)

    local out_dir = task_info.SUB_ID .. "/"
    love.filesystem.createDirectory(out_dir)
    local out_name = task_info.RUN_ID .. "_" .. os.date("%H-%M-%S") .. "_"

    -- Also save the run info (csv for human readable format)
    love.filesystem.write(out_dir .. out_name .. "log.txt", serialized)
    love.filesystem.write(out_dir .. out_name .. "events.csv", csv)
    love.filesystem.write(out_dir .. out_name .. "runtime-info.json",
                          json:encode_pretty(logger.runtime_info()))
    love.filesystem.write(out_dir .. out_name .. "stimulus-info.json",
                          json:encode_pretty(task_info))
    print(
        "Files were saved to" .. love.filesystem.getAppdataDirectory() .. "/" ..
            out_dir .. out_name .. "*")

end

local patternShader = {}
function love.load(arg)

    -- Create the shader object.
patternShader = love.graphics.newShader [[
float radial(float a, float b, float spacing_radial) {
   return sin((log(a*a + b*b))*spacing_radial);
}

float concentric(float a, float b, float spacing_concentric) {
   return sin(atan(a, b) * spacing_concentric);
}

float sign(float x) {
   return x < 0.0 ? -1.0 : x > 0.0 ? 1.0 : 0.0;
}

 extern  float sr;
  extern  float sc;

 extern  float xsize;
  extern  float ysize;

extern float oscalpha;
extern float flicker;

  vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    float a = screen_coords.x - xsize;
    float b = screen_coords.y - ysize;
    // float a = (texture_coords.x * 2.0 - 1.0) * xsize;
    // float b = (texture_coords.y * 2.0 - 1.0) * ysize;
    float check = sign(radial(a, b, sr)) * sign(concentric(a,b, sc));
    check = floor((check + 1.0) / 2.0);
    if (flicker > 0.5) {
     return vec4(flicker - check,flicker- check,flicker -check, oscalpha);
 } else {
     return vec4(check, check, check, oscalpha);
   }

  }


]]

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

    -- If task not oscillation, then the contrast will be either ON of OFF.
    task.IS_OSCILLATION = toboolean(arg[6]) or true

    -- Task timing
    task.timing = {}
    task.timing.OFFSET = tonumber(arg[7]) or 1
    task.timing.STIM_RUNTIME = 500 -- no cooldown. math.floor(246 * task.FREQUENCY) / task.FREQUENCY -- 246 = 4 minutes (240) + 6 seconds. 4:20 with offset. Then 25sec cooldown
    task.timing.TOTAL_DURATION = tonumber(arg[8]) or 50
    task.timing.RESULTS_DISPLAY_DURATION = 4
    task.ACQUISITION_DATE = os.date()

    -- Configuration of checkerboard taken from Jingyuan's matlab experiments
    task.RADIAL_SPACING = 6 -- radial spacing
    task.CONCENTRIC_SPACING = 10 -- concentric spacing
    task.FLICKER_FREQUENCY = tonumber(arg[9]) or 12 -- flickering in Hz.
    -- Configuration of the dot
    task.dot = {}
    task.dot.SIZE = 7
    -- The maximum reaction time for computing a "hit"
    task.MAX_REACTION_TIME = 0.8 -- seconds

    print(string.format(
              "Setup: Frequency=%.2f Hz, Exponent=%d, Luminance=%.2f %%, Flicker=%d Hz",
              task.FREQUENCY, task.EXPONENT, 100 * task.LUMINANCE,
              task.FLICKER_FREQUENCY))
    print("Is the stimulus a sinusoidal?", task.IS_OSCILLATION)
    print(string.format("Timing: Offset=%d s, TotalDuration=%.2f s",
                        task.timing.OFFSET, task.timing.TOTAL_DURATION))

    -- Create the checkerboard pattern
    local CHECKS = patterns.checkerboard(window.WIDTH, window.HEIGHT,
                                         task.RADIAL_SPACING,
                                         task.CONCENTRIC_SPACING)
    -- Send radial spacing and concentric spacing to shader
    patternShader:send("sr", task.RADIAL_SPACING)
    patternShader:send("sc", task.CONCENTRIC_SPACING)
    patternShader:send("xsize", window.WIDTH)
    patternShader:send("ysize", window.HEIGHT)
    patternShader:send("oscalpha", 0.0)
    patternShader:send("flicker",1.0)

    canvas = {}
    -- render_to_texture(pattern, color_LUT)
    canvas[0] = patterns.render_to_texture(CHECKS, {{0, 0, 0}, {1, 1, 1}})
    -- canvas[1] = patterns.render_to_texture(CHECKS, {{1, 1, 1}, {0, 0, 0}})

    task.IS_SCALEDNOISE = toboolean(arg[10]) or false

    if task.IS_SCALEDNOISE then
        for i = 1, 37 do
            scalednoise[i] = love.graphics.newImage(
                                 "scalednoise/pattern" .. tostring(i) .. ".png")
            scalednoise_rev[i] = love.graphics.newImage(
                                     "scalednoise/pattern" .. tostring(i) ..
                                         "rev.png")
        end

    end

    print("Is the stimulus scaled noise?", task.IS_SCALEDNOISE)

    -- Initialize stateful variables.
    state.is_running = false -- Whether the actual task has started (not waiting for trigger)
    state.is_finished = false -- Whether the task has finished (displaying the results)

    state.time = 0 -- The experimental clock in seconds. Kicks off after the trigger is received.
    state.flicker_time = 0 -- this keeps track of how much time has passed in flicker cycles
    state.modulation_time = -task.timing.OFFSET * task.FREQUENCY -- this keeps track of how much the oscillation has evolved
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
    love.graphics.setBackgroundColor(task.LUMINANCE / 2, task.LUMINANCE / 2,
                                     task.LUMINANCE / 2)
    love.mouse.setVisible(false)
    love.graphics.setFont(love.graphics.newFont(30))

end

local title = nil
function love.update(dt)
    -- Hold off the stateful clocks until we receive the first trigger.
    if not state.is_running then return end

    -- Advance clock.
    state.time = state.time + dt
    -- debug_start = love.timer.getTime()
    -- Advance flicker normalized by flicker rate (change independent of FPS)
    state.flicker_time = state.flicker_time + task.FLICKER_FREQUENCY * dt
    -- Advance modulation clock
    state.modulation_time = state.modulation_time + task.FREQUENCY * dt
    -- Advance dot reaction time clock
    dot.clock = dot.clock + dt

    if task.IS_SCALEDNOISE then
        -- Divide the state.flicker_time by 2 so that the canvas is shown for both positive and negative within 1 flicker cycle.
        canvas[0] = scalednoise[math.floor(state.flicker_time / 2) % 37 + 1]
        canvas[1] = scalednoise_rev[math.floor(state.flicker_time / 2) % 37 + 1]
    end

    if dot.clock > dot.current_isi then
        dot.clock = dot.clock - dot.current_isi -- Reset the clock and loop for new ISI
        if not state.is_finished then
            love.event.push("log", state.time, dot.current_isi,
                            state.trigger_count, "DOT_FLIP", "N/A",
                            dot.is_active and 1 or 0)
        end
        dot.current_isi = mathutils.random_float(0.8, 3)
        if dot.is_active then
            dot.color = {0.8, 0, 0}
        else
            dot.color = {0.5, 0, 0}
        end
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
            print(string.format("Average Reaction Time = %.2f seconds",
                                results.avg_rt))

            love.event.push("log", state.time, 0, state.trigger_count, "FINISH",
                            "N/A", string.format("%.2f %%", results.hitrate))
        end
        if not state.is_finished then
            print("Task finished at: " .. os.date())
        end
        state.is_finished = true
        state.results_display_time_left = state.results_display_time_left - dt
    end
    local oldtitle = title
    title = love.timer.getFPS()
    if title ~= oldtitle then love.window.setTitle(title) end

    if not state.is_finished then
        -- This means experiment started, but we are waiting for a steady state.
        if (state.time < task.timing.OFFSET) or
            (state.time > task.timing.OFFSET + task.timing.STIM_RUNTIME) then
            state.phase = math.pi
            state.alpha = 0
        else
            local alpha_offset = 1 -- So that alpha ranges from 0 to 2, instead of -1 to 1.
            local alpha_normalization = 2 -- So that alpha ranges from 0 to 1, instead of 0 to 2.
            state.phase = (state.modulation_time + 0.5) % 1 * 2 * math.pi
            if task.IS_OSCILLATION then
                state.alpha = ((math.cos(state.phase) + alpha_offset) /
                                  alpha_normalization) ^ task.EXPONENT *
                                  task.LUMINANCE
            else -- ON/OFF at given frequency
                state.alpha = state.phase >= math.pi and task.LUMINANCE or 0
            end
        end

        patternShader:send("oscalpha", state.alpha)
        local flicker = math.floor(state.flicker_time) % 2
        patternShader:send("flicker", flicker)

    end

end

function love.draw()
    -- The hold means that we are waiting for a trigger, so we don't start the experiment.
    if not state.is_running then
        love.graphics.setColor(0.6, 0, 0)
        love.graphics.printf("The task will begin shortly...", 0,
                             2 * window.HEIGHT / 5, window.WIDTH, 'center')
        -- Draw the dot
        love.graphics.setColor(dot.color)
        -- love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.circle("fill", window.WIDTH / 2, window.HEIGHT / 2,
                             task.dot.SIZE)
        return
    end

    if state.is_finished then
        local hitrate_str = string.format("Hit Rate = %.2f %%", results.hitrate)
        local avg_rt_str = string.format("Average Reaction Time = %.2f seconds",
                                         results.avg_rt)

        love.graphics.setColor(0.6, 0, 0)

        love.graphics.printf("Your task results:", 0,
                             2 * window.HEIGHT / 5 - 30, window.WIDTH, 'center')
        love.graphics.printf(hitrate_str, 0, 2 * window.HEIGHT / 5 + 20,
                             window.WIDTH, 'center')
        love.graphics.printf(avg_rt_str, 0, 2 * window.HEIGHT / 5 + 70,
                             window.WIDTH, 'center')

        if state.results_display_time_left < 0 then
            save_data(events, task)
            love.event.quit()
        end
        return
    end

    love.graphics.setColor(1, 1, 1)
    -- Draw the texture
    -- love.graphics.setBlendMode("alpha")
    -- love.graphics.draw(canvas[math.floor(state.flicker_time) % 2])
    -- love.graphics.setCanvas(canvas[0])

    love.graphics.setShader(patternShader)
    -- love.graphics.setCanvas()
    -- love.graphics.draw(canvas[0])
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setShader()

    -- if state.is_running then
    --    debug_end = love.timer.getTime()
    --    love.event.push(
    --       "log", state.time, debug_start, debug_end, "DRAW", "N/A", debug_end - debug_start
    --    )
    -- end

    -- Draw a shim around the dot
    love.graphics.setColor(task.LUMINANCE / 2, task.LUMINANCE / 2,
                           task.LUMINANCE / 2)
    love.graphics.circle("fill", window.WIDTH / 2, window.HEIGHT / 2,
                         task.dot.SIZE + 5)
    -- Draw the dot
    love.graphics.setColor(dot.color)
    love.graphics.circle("fill", window.WIDTH / 2, window.HEIGHT / 2,
                         task.dot.SIZE)

    -- Debug clocks
    -- if true then
    --    love.graphics.setColor(0.7, 0, 0)
    --    love.graphics.printf(state.time, 0, window.HEIGHT/5, window.WIDTH, 'center')
    --    love.graphics.printf(state.modulation_time, 0, 2*window.HEIGHT/5, window.WIDTH, 'center')
    -- end

    -- if dot.draw_pressed then
    --    if reactions[#reactions] == 1 then
    --       love.graphics.setColor(0,1,0)
    --    else
    --       love.graphics.setColor(1,0,0)
    --    end
    --    love.graphics.circle("line", window.WIDTH/2, window.HEIGHT/2, task.dot.SIZE)
    -- end

    -- If the experiment has finished, show the average reaction time and the hit rate.
end

function love.handlers.log(onset, duration, sample, trial_type, response_time,
                           value)
    events[#events + 1] = {
        onset, duration, sample, trial_type, response_time, value
    }
end

-- Handle keypresses.
function love.keypressed(key, scancode)
    if key == "escape" then
        -- Don't push it to the async event logger because we will save and quit immediately.
        events[#events + 1] = {
            state.time, 0, state.trigger_count, "CANCELLED", "n/a", "n/a"
        }
        save_data(events, task)
        print("The run was cancelled after ", state.time, " seconds.")
        love.event.quit()
    end

    -- Received trigger
    if key == "=" then
        state.trigger_count = state.trigger_count + 1
        love.event.push("log", state.time, 0, state.trigger_count, "TRIGGER",
                        state.phase, math.floor(state.modulation_time + 0.5))
        state.is_running = true

        if state.trigger_count == 0 then
            print("Task started at: " .. os.date())
        end
    end

    -- Received keypress
    if key == "1" or key == "2" or key == "3" or key == "4" or key == "0" or key ==
        "5" or key == "6" or key == "7" or key == "8" then

        state.keypress.onset[key] = state.time
        state.keypress.reaction_time[key] = dot.clock

        reaction_times[#reaction_times + 1] = dot.clock
        -- 1 if clock < max reaction time, 0 otherwise
        reactions[#reactions] = dot.clock < task.MAX_REACTION_TIME and 1 or 0

        dot.draw_pressed = true
    end

    if key == "s" then
        love.graphics.captureScreenshot(tostring(state.phase) .. ".png")
    end
end

function love.keyreleased(key, scancode)
    if key == "1" or key == "2" or key == "3" or key == "4" or key == "0" then
        local duration = state.time - state.keypress.onset[key]
        love.event.push("log", state.keypress.onset[key], duration,
                        state.trigger_count, "KEYPRESS",
                        state.keypress.reaction_time[key], key)

        dot.draw_pressed = false
    end
end
