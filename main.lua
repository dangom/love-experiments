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
-----------------------------------------------------------------------------

require("checkerboard")

math.randomseed(os.clock()*100000000000)

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
   local width, height = love.graphics.getDimensions()

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
   flickerrate = 12 -- flickering per second.
   dtotal = 0   -- this keeps track of how much time has passed
   offset = 2 -- seconds before stimulus starts

   -- The time it takes for an initial dot color change (uniform rand from 0.8 to 3s)
   dot_change = math.random(0.8, 3)
   -- The dot clock
   dot_clock = 0
   -- Whether the dot is active
   dot_on = true
   dot_color = {0.5, 0, 0}

   -- Maximum acceptable reaction time for color changing.
   maxrt = 0.5

   -- This is a dummy variable indicating that the experiment hasn't started.
   -- It signals that the trigger has not been received yet.
   hold = true

   events = {} -- The events that will be saved to the logfile.

   -- The background color, which should eventually depend on the target luminance.
   love.graphics.setBackgroundColor(0.5, 0.5, 0.5)

end

function love.update(dt)

   if hold then
      return
   end

   time = time + dt
   dot_clock = dot_clock + dt
   local change = flickerrate * dt

    -- we add the time passed since the last update, probably a very small number like 0.01
   dtotal = dtotal + change
   if dtotal >= 1 then
      -- reduce our timer by a second, but don't discard the change... what if our framerate is 2/3 of a second?
      dtotal = dtotal - 1

      -- Record that the screen has flickered.
      -- events[#events + 1] = {time, "flicker"}

      if canvas == canvas_forward then
         canvas = canvas_backward
      else
         canvas = canvas_forward
      end
   end

   -- Handle the dot
   if dot_clock > dot_change then
      dot_clock = dot_clock - dot_change
      dot_change = math.random(0.8, 3)
      if dot_on then
         dot_color = {0.8, 0, 0}
         dot_on = false
      else
         dot_color = {0.5, 0, 0}
         dot_on = true
      end

   end

end

function love.draw()

   -- The hold means that we are waiting for a trigger, so we don't start the experiment.
   if hold then
      return
   end


   -- very important!: reset color before drawing to canvas to have colors properly displayed
   -- see discussion here: https://love2d.org/forums/viewtopic.php?f=4&p=211418#p211418

   if time < offset then
      alpha = 0
   else
      alpha=(((math.sin((time-offset-1/0.1/4)*0.1*math.pi*2)+1)/2)^1)
      if alpha < 0.000001 then
         events[#events + 1] = {time, "phase", alpha}
      end
   end
   love.graphics.setColor(1, 1, 1, alpha)

   -- The rectangle from the Canvas was already alpha blended.
   -- Use the premultiplied alpha blend mode when drawing the Canvas itself to prevent improper blending.
   -- love.graphics.setBlendMode("alpha", "premultiplied")

   love.graphics.setBlendMode("alpha")
   love.graphics.draw(canvas)
   love.graphics.setColor(dot_color)
   love.graphics.circle("fill", width/2, height/2, 10, 100)

end

function love.keypressed(key, scancode, isrepeat)
   if key == "escape" then
      serialized = lume.serialize(events)
      -- The filetype actually doesn't matter, and can even be omitted.
      love.filesystem.write("savedata.txt", serialized)
      love.event.quit()
   end

   if key == "=" then
      events[#events + 1] = {time, "trigger", key}
      hold = false
   end

   if key == "1" then
      if dot_clock < maxrt then
         response = "true"
      else
         response = "false"
      end
      events[#events + 1] = {time, "keypress", dot_clock, response}
   end
end

