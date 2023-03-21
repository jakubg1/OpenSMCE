local Network = require("src.Kernel.Network")

local outID, data = ...
local out = love.thread.getChannel(outID)

local outData = Network.get(data.self, data.url, data.expectResJSON)

out:push(outData)