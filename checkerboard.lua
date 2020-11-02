-----------------------------------------------------------------------------
-- Auxiliary functions to generate a flickering checkerboard
-- Author: Daniel Gomez
-- Date: 10.31.2020
-----------------------------------------------------------------------------

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
math.sign = math.sign or function(x) return x<0 and -1 or x>0 and 1 or 0 end

-- The checkerboard generation
function checkerboard(size_x, size_y, sr, sc)
   local lx = linspace(-1, 1, size_y)
   local ly = linspace(-1, 1, size_x)
   local x, y = meshgrid(lx, ly)

   checks = {}
   for i, row in ipairs(x) do
      checks[i] = {}
      for j, tile in ipairs(row) do
         local a = x[i][j]
         local b = y[i][j]
         local check =  math.sign(radial(a, b, sr)) * math.sign(concentric(a,b, sc))
         checks[i][j] = math.floor((check + 1) / 2)
      end
   end

   return checks

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

-- Generate a random (uniform) floating number between low and high
function random_float(low, high)
   return low + math.random()  * (high - low)
end
