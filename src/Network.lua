local class = require "com.class"
local json = require("com.json")
local socket = require("socket")
-- TODO: Remove pcall wrapper once 12.0 is fully supported.
local httpsw, https = pcall(function() return require("https") end)

---@class Network
---@overload fun():Network
local Network = class:derive("Network")

--[[
    DEV NOTES:
    Keep in mind that HTTPS requests are only possible within LOVE 12.0. Building the
    DLLs for <11.4 may be possible but stack overflow errors have occured during testing
    (indicated by the unhelpful "Failed to initialize filesystem" error).
    See more: https://love2d.org/wiki/lua-https
    There are no fields for now, feel free to add/change stuff here as more networking
    functionalities are added.
    Note: Use threaded versions of functions, the unthreaded ones block the main process!!
]]

--- Initializes the Network class.
function Network:new()
    self.USER_AGENT = "OpenSMCE"
end

---Sends a `GET` request to a specified URL.
---
---Return table fields:
---- `code`: The HTTPS code (or 0 if it fails).
---- `body`: The response body (or `nil` if it fails).
---@param url string The URL to send the `GET` request to.
---@param expectResJSON? boolean Expects a JSON response and serializes it.
---@return { code: number|0, body: string|nil }
function Network:get(url, expectResJSON)
	-- TODO: Failsafe for 11.x; remove after 12.0 is fully supported.
	if not httpsw or not https then
		return {code = 0}
	end

    local code, body = https.request(url, {
        headers = {["User-Agent"] = self.USER_AGENT}
    })
    body = expectResJSON and json.encode(body) or body
    return {code = code, body = body}
end

---Sends a `GET` request to a specified URL on a separate thread.
---
---Return table fields (this table is the only argument in the `onFinish` function):
---- `code`: The HTTPS code (or 0 if it fails).
---- `body`: The response body (or `nil` if it fails).
---@param url string The URL to send the `GET` request to.
---@param expectResJSON? boolean Expects a JSON response and serializes it.
---@param onFinish function The function to be executed when the request finishes.
function Network:getThreaded(url, expectResJSON, onFinish)
    _ThreadManager:startJob("networkGet", {self = self, url = url, expectResJSON = expectResJSON}, onFinish)
end

---Sends a `POST` request with a serialized JSON as it's request body to a specified URL.
---
---Return table fields:
---- `code`: The HTTPS code (or 0 if it fails).
---- `body`: The response body (or `nil` if it fails).
---- `resHeaders`: Response headers (or `nil` if it fails).
---@param url string The URL to send the `POST` request to.
---@param tbl table The table to serialize to JSON.
---@param expectResJSON? boolean Expects a JSON response and serializes it.
---@return { code: number|0, body: string|nil, resHeaders: table|nil }
function Network:postSerialized(url, tbl, expectResJSON)
	-- TODO: Failsafe for 11.x; remove after 12.0 is fully supported.
	if not httpsw or not https then
		return {code = 0}
	end

    local code, body, headers = https.request(url, {
        method = "post",
        headers = {
            ["User-Agent"] = self.USER_AGENT,
            ["Content-Type"] = "application/json"
        },
        data = json.encode(tbl)
    })
    body = expectResJSON and json.encode(body) or body
    return {code = code, body = body, resHeaders = headers}
end

---Sends a `POST` request with a serialized JSON as it's request body to a specified URL
---on a separate thread.
---
---Return table fields (this table is the only argument in the `onFinish` function):
---- `code`: The HTTPS code (or 0 if it fails).
---- `body`: The response body (or `nil` if it fails).
---- `resHeaders`: Response headers (or `nil` if it fails).
---@param url string The URL to send the `POST` request to.
---@param tbl table The table to serialize to JSON.
---@param expectResJSON? boolean Expects a JSON response and serializes it.
---@param onFinish function The function to be executed when the request finishes.
function Network:postSerializedThreaded(url, tbl, expectResJSON, onFinish)
    _ThreadManager:startJob("networkPostSerialized", {self = self, url = url, tbl = tbl, expectResJSON = expectResJSON}, onFinish)
end

---Opens a socket on the specified IP and port for other peers to connect to.
---If the operation fails, returns `nil`.
---@param ip string The IP address to open the socket on. Must be a valid IPv4 address. `"localhost"` is not allowed, use `"127.0.0.1"` instead.
---@param port integer The port number to open the socket on. Must be a free port.
---@return socket.udp?
function Network:udpHost(ip, port)
    local udp = socket.udp()
    udp:settimeout(0)
    local success = udp:setsockname(ip, port)
    return success and udp
end

---Opens a socket and connects to another socket on the specified IP and port.
---If the operation fails, returns `nil`.
---@param ip string The IP address of the server. Must be a valid IPv4 address. `"localhost"` is not allowed, use `"127.0.0.1"` instead.
---@param port integer The port number of the server.
---@return socket.udp?
function Network:udpJoin(ip, port)
    local udp = socket.udp()
    udp:settimeout(0)
    local success = udp:setpeername(ip, port)
    return success and udp
end

return Network