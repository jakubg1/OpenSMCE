local Class = require("com.class")

---@class UserList : Class
---@overload fun(): UserList
local UserList = Class:derive("UserList")

---Creates a new User List.
---This is a class which stores the list of all clients connected to the Networking Test party.
function UserList:new()
    ---@alias User {ip: string, port: integer, atime: number}
    ---@type table<string, User>
    self.users = {} -- A list of connected users, keyed by names. Remains empty if this user is not a host.
    ---@type table<string, table<integer, string>>
    self.nameLookup = {} -- A lookup list, keyed first by IP addresses and then by port numbers, to get the user name.
end

---Returns the data of the User connected to this party.
---Returns `nil` if the provided user doesn't exist.
---@param name string The name of the user.
---@return User
function UserList:getUser(name)
    return self.users[name]
end

---Returns the list of all users.
---@return table<string, User>
function UserList:getUsers()
    return self.users
end

---Adds a user to the `self.users` and `self.nameLookup` lists.
---@param ip string The IP address of the connected user.
---@param port integer The port number of the connected user.
---@param name string The name of the connected user.
function UserList:addUser(ip, port, name)
    assert(not self.users[name], "The user " .. name .. " already exists.")
    self.users[name] = {ip = ip, port = port}
    self.nameLookup[ip] = self.nameLookup[ip] or {}
    self.nameLookup[ip][port] = name
end

---Renames a user in the `self.users` and `self.nameLookup` lists.
---@param oldName string The current user name. If the user does not exist, this function will throw an error.
---@param newName string The new user name. If another user does exist with this name, this function will throw an error.
function UserList:renameUser(oldName, newName)
    assert(self.users[oldName], "The user " .. oldName .. " doesn't exist.")
    assert(not self.users[newName], "The user " .. newName .. " already exists.")
    local ip, port = self.users[oldName].ip, self.users[oldName].port
    self.users[newName] = self.users[oldName]
    self.users[oldName] = nil
    self.nameLookup[ip][port] = newName
end

---Removes a user from the `self.users` and `self.nameLookup` lists.
---@param name string The name of the user.
function UserList:removeUser(name)
    assert(self.users[name], "The user " .. name .. " doesn't exist.")
    local ip, port = self.users[name].ip, self.users[name].port
    self.users[name] = nil
    self.nameLookup[ip][port] = nil
end

---Removes all users from the `self.users` and `self.nameLookup` tables.
function UserList:empty()
    _Utils.emptyTable(self.users)
    _Utils.emptyTable(self.nameLookup)
end

---Returns the name of the user connected to the provided IP and port.
---Returns `nil` if nobody is connected there.
---@param ip string The IP address of the connected user.
---@param port integer The port number of the connected user.
---@return string?
function UserList:getUserNameFromSocket(ip, port)
    return self.nameLookup[ip] and self.nameLookup[ip][port]
end

---Returns the first free username, starting with `"Guest1"`, `"Guest2"` and so on.
---@return string
function UserList:getNewUserName()
    local n = 1
    while self.users["Guest" .. n] do
        n = n + 1
    end
    return "Guest" .. n
end

return UserList