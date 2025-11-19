-- Welcome to the Test File!
-- Each file tests a certain aspect of the engine.
-- The tests are actually a pretty good resource to also learn how the modules work!
-- Setting them up is also really simple:
-- 1. Require any necessary modules. Ideally, only the ones you want to test.
-- 2. Declare a table and return it. This is so that the functions can be listed and tested.
-- 3. In the table, create as many functions as you want! Each function will be run separately.
-- 
-- The test is considered passed when either `nil` or `true` is returned.
-- The test is considered failed when either `false` is returned or the test crashes!
-- You will get the full traceback in the log if the test crashes, so you can inspect and fix it!
-- Have fun testing!

local Color = require("src.Essentials.Color")
local f = {}

function f.testOneComponent()
    local val = math.random()
    local color = Color(val)
    return color.r == val and color.g == val and color.b == val
end

function f.testThreeComponents()
    local r, g, b = math.random(), math.random(), math.random()
    local color = Color(r, g, b)
    return color.r == r and color.g == g and color.b == b
end

function f.testWhiteHexCode()
    local color = Color(1, 1, 1)
    return color:getHex() == "#ffffff"
end

function f.testBlackHexCode()
    local color = Color(0, 0, 0)
    return color:getHex() == "#000000"
end

function f.testGrayHexCode()
    local color = Color(0.5, 0.5, 0.5)
    return color:getHex() == "#7f7f7f"
end

function f.testGreenHexCode()
    local color = Color(0, 1, 0)
    return color:getHex() == "#00ff00"
end

function f.testSameHexCode()
    local color = Color("#e07424")
    return color:getHex() == "#e07424"
end

function f.testRandomHexCodes()
    for i = 1, 100 do
        local hex = string.format("#%06x", math.random(0, 2^24-1))
        local color = Color(hex)
        if color:getHex() ~= hex then
            error("Failed with hex code: " .. hex)
        end
    end
    return true
end

return f