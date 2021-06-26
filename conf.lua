local json = require("com/json")



local function loadSettingConsole()
	-- Open engine/settings.json and read whether there should be a console open.
	local file = io.open("engine/settings.json")
	if not file then
		return true -- defaults to true
	end
	io.input(file)
	local contents = json.decode(io.read("*a"))
	io.close(file)

	local setting = contents.consoleWindow
	return setting
end



function love.conf(t)
	t.console = loadSettingConsole()
	print("using console: " .. tostring(t.console))
end
