local utf8 = require("utf8")



local CrashScreen = require("src/Kernel/CrashScreen")
local crashScreen = nil
local DT = 0.1



local function error_printer(msg, layer)
	_Log:printt("crash", (debug.traceback("Error: " .. tostring(msg), 1+(layer or 1)):gsub("\n[^\n]+$", "")))
end
 
function love.errorhandler(msg)
	msg = tostring(msg)
	
	error_printer(msg, 2)

	if _Log then
		_Log:save(true)
	end
	
	if not love.window or not love.graphics or not love.event then
		return
	end
	
	if not love.graphics.isCreated() or not love.window.isOpen() then
		local success, status = pcall(love.window.setMode, 800, 600)
		if not success or not status then
			return
		end
	end
	
	-- Reset state.
	if love.mouse then
		love.mouse.setVisible(true)
		love.mouse.setGrabbed(false)
		love.mouse.setRelativeMode(false)
		if love.mouse.isCursorSupported() then
			love.mouse.setCursor()
		end
	end
	if love.joystick then
		-- Stop all joystick vibrations.
		for i,v in ipairs(love.joystick.getJoysticks()) do
			v:setVibration()
		end
	end
	if love.audio then love.audio.stop() end
	
	love.graphics.reset()
	local font = love.graphics.setNewFont(14)
	
	local trace = debug.traceback()
	
	love.graphics.origin()
	
	if _DiscordRPC then _DiscordRPC:disconnect() end
	
	local sanitizedmsg = {}
	for char in msg:gmatch(utf8.charpattern) do
		table.insert(sanitizedmsg, char)
	end
	sanitizedmsg = table.concat(sanitizedmsg)
	
	local err = {}
	
	table.insert(err, sanitizedmsg)
	
	if #sanitizedmsg ~= #msg then
		table.insert(err, "Invalid UTF-8 string in error message.")
	end
	
	table.insert(err, "\n")
	
	for l in trace:gmatch("(.-)\n") do
		if not l:match("boot.lua") then
			l = l:gsub("stack traceback:", "Traceback:\n")
			table.insert(err, l)
		end
	end
	
	local p = table.concat(err, "\n")
	
	p = p:gsub("\t", "")
	p = p:gsub("%[string \"(.-)\"%]", "%1")
	
	crashScreen = CrashScreen(p)
	
	return function()
		love.event.pump()
 
		for e, a, b, c in love.event.poll() do
			if e == "quit" then
				return 1
			elseif e == "keypressed" and a == "escape" then
				return 1
			elseif e == "mousepressed" then
				crashScreen:mousepressed(a, b, c)
			elseif e == "mousereleased" then
				crashScreen:mousereleased(a, b, c)
			end
		end
		
		love.graphics.clear(0, 0, 0)
		crashScreen:update(DT)
		crashScreen:draw()
		love.graphics.present()
 
		if love.timer then
			love.timer.sleep(DT)
		end
	end
end