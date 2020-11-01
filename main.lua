-----------------------------------------------------------------------------
-- Run a flickering checkerboard visual experiment

-- Goals:
-- [X] Flicker at a given frequency regardless of FPS
-- [X] Modulate the intensity of the flickering (osc stimuli)
-- [X] Randomly flicker a red dot
-- [ ] Log all keypresses and their time in milliseconds from start of experiment
-- [X] Exit on escape
-- [ ] Give feedback when experiment ends

-- Author: Daniel Gomez
-- Date: 10.31.2020
-----------------------------------------------------------------------------

require("checkerboard")

math.randomseed(os.clock()*100000000000)

function love.load()
   lume = require("lume")

   -- love.window.setFullscreen(true, "desktop")
   width, height = love.graphics.getDimensions()
   sr = 6 -- radial spacing
   sc = 10 -- concentric spacing
   checks = checkerboard(width, height, sr, sc)

   --Create a table named colors
    colors_forward = {
        --Fill it with tables filled with RGB numbers
        {1, 1, 1},
        {0, 0, 0},
    }
    colors_backward = {
       --Fill it with tables filled with RGB numbers
        {0, 0, 0},
        {1, 1, 1},
    }

    canvas_forward = love.graphics.newCanvas(width, height)
    canvas_backward = love.graphics.newCanvas(width, height)
    -- Rectangle is drawn to the canvas with the regular alpha blend mode.
    love.graphics.setCanvas(canvas_forward)
        love.graphics.clear()
        love.graphics.setBlendMode("alpha")
        for i,row in ipairs(checks) do
           for j,tile in ipairs(row) do
              --First check if the tile is not zero
              love.graphics.setColor(colors_forward[tile+1])
              --Draw the tile
              love.graphics.rectangle("fill", i, j, 1, 1)
           end
        end
    love.graphics.setCanvas()

    love.graphics.setCanvas(canvas_backward)
        love.graphics.clear()
        love.graphics.setBlendMode("alpha")
        for i,row in ipairs(checks) do
           for j,tile in ipairs(row) do
              --First check if the tile is not zero
              love.graphics.setColor(colors_backward[tile+1])
              --Draw the tile
              love.graphics.rectangle("fill", i, j, 1, 1)
           end
        end
    love.graphics.setCanvas()

    canvas = canvas_forward

    time = 0
    dtotal = 0   -- this keeps track of how much time has passed
    flickerrate = 12 -- flickering per second.
    offset = 5 -- seconds before stimulus starts

    dot_change = math.random(0.8, 3)
    dot_clock = 0
    dot_on = true
    dot_color = {0.5, 0, 0}

    hold = true

    events = {}
    love.graphics.setBackgroundColor(0.5, 0.5, 0.5)

end

function love.update(dt)

   if hold then
      return
   end

   time = time + dt
   dot_clock = dot_clock + dt
   local change = flickerrate * dt

   dtotal = dtotal + change   -- we add the time passed since the last update, probably a very small number like 0.01
   if dtotal >= 1 then
      dtotal = dtotal - 1   -- reduce our timer by a second, but don't discard the change... what if our framerate is 2/3 of a second?
      if canvas == canvas_forward then
         canvas = canvas_backward
      else
         canvas = canvas_forward
      end
   end

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
      love.filesystem.write("logfiles/savedata.txt", serialized)
      love.event.quit()
   end

   if key == "=" then
      hold = false
   end

   if key == "1" then
      events[#events + 1] = {time, "keypress", key}
   end
end

