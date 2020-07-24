--[[

List1.lua

An one-dimensional list utility to help managing various lists, e.g. lists of particles or lists of spheres.

Rules:
- This list implementation allows to contain objects only. No tables, integers, strings or booleans. Nested lists are okay.
- An object that is in this list may neither be in any other list nor in the same list twice or more times.
- That object also will have a special _list field which will allow the object to e.g. delete itself from the list using self._list:destroy(self).

]]

-- Class identification
local class = require "class"
local List1 = class:derive("List1")



function List1:new()
	self.objects = {}
	self.locked = false
end

-- Adds an object to the list.
function List1:append(object)
	table.insert(self.objects, object)
	object._list = self
end

-- Adds an object to the list, placed BEFORE the object with specified index (the index specified will be the index of that object in the table).
function List1:insert(object, index)
	table.insert(self.objects, index, object)
	object._list = self
end

-- Removes an object from the list, based on the index.
function List1:remove(index)
	local object = self.objects[index]
	
	-- If the list is locked, the item is only queued for deletion.
	if self.locked then
		object._delQueue = true
		return
	end
	
	table.remove(self.objects, index)
	object._list = nil
end

-- Deletes all items from the list.
function List1:clear()
	self:iterate(function(i, o) self:remove(i) end)
end

-- Deletes all items that were queued for deletion.
function List1:cleanup()
	for i = #self.objects, 1, -1 do
		if self:get(i)._delQueue then self:remove(i) end
	end
end

-- Destroys a given object from the list.
function List1:destroy(object)
	self:remove(self:index(object))
end

-- Gets an index of the given object in the list. If none found, return nil.
function List1:index(object)
	for i, o in ipairs(self.objects) do
		if object == o then return i end
	end
	return nil
end

-- Gets an object from the list with a given index.
function List1:get(index)
	return self.objects[index]
end

-- Returns whether the list is empty.
function List1:empty()
	return #self.objects == 0
end

-- Iterates through all objects in the list and executes a function on each one. The parameters are: index, object.
-- Because items can be deleted through the iteration, rendering some items to be skipped, the list is locked for a while and then the cleanup of the list is performed.
function List1:iterate(f)
	self.locked = true
	for i, o in ipairs(self.objects) do f(i, o) end
	self.locked = false
	self:cleanup()
end



return List1