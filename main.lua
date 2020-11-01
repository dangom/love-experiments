function linspace(start, stop, size)
   -- Same as linspace in matlab
   local x = {}
   local diff = stop - start
   for i=0, size-1 do
      x[i+1] = start + i * (diff/(size-1))
   end
   return x
end

-- function print_table(t)
--    print(table.concat(t, ", "))
-- end

function meshgrid(x, y)
   -- Same as meshgrid in matlab
   local xx = {}
   local yy = {}

   for i=1, #y do
      xx[i] = {}
      yy[i] = {}
      for j=1, #x do
         xx[i][j] = x[j]
         yy[i][j] = y[i]
      end
   end
   return xx, yy

end

function radial(a, b, spacing_radial)
   return math.sin((math.sqrt(a*a + b*b)^0.3)*2*math.pi*spacing_radial)
end

function concentric(a, b, spacing_concentric)
   return math.sin(math.atan2(a, b) * spacing_concentric)
end

math.sign = math.sign or function(x) return x<0 and -1 or x>0 and 1 or 0 end

function love.load()
   width, height = love.graphics.getDimensions()
   lx = linspace(-1, 1, height)
   ly = linspace(-1, 1, width)
   x, y = meshgrid(lx, ly)

   sr = 10
   sc = 15

   checks = {}
   for i, row in ipairs(x) do
      checks[i] = {}
      for j, tile in ipairs(row) do
         a = x[i][j]
         b = y[i][j]
         check =  math.sign(radial(a, b, sr)) * math.sign(concentric(a,b, sc))
         checks[i][j] = math.floor((check + 1) / 2)
      end
   end

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
