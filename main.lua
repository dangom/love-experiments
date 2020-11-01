require("checkerboard")

function love.load()
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

    colors = colors_forward
end

function love.update()
   if colors == colors_forward then
      colors = colors_backward
   else
      colors = colors_forward
   end
end

function love.draw()
    for i,row in ipairs(checks) do
        for j,tile in ipairs(row) do
            --First check if the tile is not zero
                love.graphics.setColor(colors[tile+1])
                --Draw the tile
                love.graphics.rectangle("fill", i, j, 1, 1)
        end
    end
end
