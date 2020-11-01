require("checkerboard")

function love.load()
   -- love.window.setFullscreen(true, "desktop")
   width, height = love.graphics.getDimensions()
   sr = 10 -- radial spacing
   sc = 15 -- concentric spacing
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
    flickerrate = 8 -- flickering per second.

end

function love.update(dt)

   time = time + dt
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

end

function love.draw()
-- very important!: reset color before drawing to canvas to have colors properly displayed
   -- see discussion here: https://love2d.org/forums/viewtopic.php?f=4&p=211418#p211418
    alpha=(((math.sin((time-0-1/0.1/4)*0.1*math.pi*2)+1)/2)^1)
    love.graphics.setColor(alpha, alpha, alpha, 1)
    -- The rectangle from the Canvas was already alpha blended.
    -- Use the premultiplied alpha blend mode when drawing the Canvas itself to prevent improper blending.
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.draw(canvas)

end
