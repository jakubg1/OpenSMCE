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

local Expression = require("src.Expression")
local f = {}

function f.testAddition()
    local expr = Expression("${2+2}")
    local result = expr:evaluate()
    return result == 4
end

function f.testSubtraction()
    local expr = Expression("${4-2}")
    local result = expr:evaluate()
    return result == 2
end

function f.testDivision()
    local expr = Expression("${10/2}")
    local result = expr:evaluate()
    return result == 5
end

function f.testDivisionByZero()
    local expr = Expression("${10/0}")
    local result = expr:evaluate()
    return result == math.huge
end

return f