-----------------------------------------------------------------------------
-- Auxiliary functions to generate a flickering checkerboard
-- Author: Daniel Gomez
-- Date: 10.31.2020
-----------------------------------------------------------------------------
local math = require("math")
local patterns = {}

-- Same as linspace in matlab
local function linspace(start, stop, size)
   local x = {}
   local diff = stop - start
   for i=0, size-1 do
      x[i+1] = start + i * (diff/(size-1))
   end
   return x
end

-- Same as meshgrid in matlab
local function meshgrid(x, y)
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

-- Auxiliary function to generate values acording to angle
local function radial(a, b, spacing_radial)
   return math.sin((math.sqrt(a*a + b*b)^0.3)*2*math.pi*spacing_radial)
end

-- Auxiliary function to generate values acording to radius
local function concentric(a, b, spacing_concentric)
   return math.sin(math.atan2(a, b) * spacing_concentric)
end

-- sign function
local sign = math.sign or function(x) return x<0 and -1 or x>0 and 1 or 0 end

-- The checkerboard generation
patterns.checkerboard = function(size_x, size_y, sr, sc)
   local lx = linspace(-1, 1, size_y)
   local ly = linspace(-1, 1, size_x)
   local x, y = meshgrid(lx, ly)

   local checks = {}
   for i, row in ipairs(x) do
      checks[i] = {}
      for j, _ in ipairs(row) do
         local a = x[i][j]
         local b = y[i][j]
         local check =  sign(radial(a, b, sr)) * sign(concentric(a,b, sc))
         checks[i][j] = math.floor((check + 1) / 2)
      end
   end

   return checks

end

-- Creates a canvas an renders an array to it.
-- Assumes that colorcode has 2 entries, one for 0 and one for 1.
patterns.render_to_texture = function(array, colorcode)
   -- Take that the array has the size of the screen.
   local width = #array
   local height = #array[1]
   local canvas = love.graphics.newCanvas(width, height)
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

return patterns
