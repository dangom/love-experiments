local math = require("math")
local mathutils = {}

-- Sum all elements of a table
mathutils.sum = function(t)
    local sum = 0
    for _, v in pairs(t) do
       if type(v) == "number" then
          sum = sum + v
       end
    end

    return sum
end

-- Generate a random (uniform) floating number between low and high
mathutils.random_float = function(low, high)
   return low + math.random()  * (high - low)
end

return mathutils
