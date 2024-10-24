local Network = require("src.Network")

local outID, data = ...
local out = love.thread.getChannel(outID)

local outData = Network.postSerialized(data.self, data.url, data.tbl, data.expectResJSON)

out:push(outData)