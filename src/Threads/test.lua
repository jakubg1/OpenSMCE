-- This is an example thread file.
-- It throws some garbage in the console and then returns the result of adding two numbers.
-- Example usage:
-- _ThreadManager:startJob("test", {a = 2, b = 5}, function(result) print("He finished!!! And the result is " .. tostring(result.result) .. "!") end)

-- Get the data from ThreadManager and connect to a unique channel provided by it.
local outID, data = ...
local out = love.thread.getChannel(outID)

-- Do some long and time expensive stuff.
for i = 1, 1000 do
    print(i)
end

-- Prepare data for returning.
local outData = {
    result = data.a + data.b
}

-- Return data.
out:push(outData)