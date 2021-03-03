local HttpService = game:GetService("HttpService")
local backend_url = "https://7iokpqos42.execute-api.us-west-2.amazonaws.com/prod"

local function ends_with(str, ending)
	print("Checking string ending")
	print(str .. ", " .. str:sub(-#ending))
	return ending == "" or str:sub(-#ending) == ending
end

local function is_blox_script(filename)
	return ends_with(filename, ".blox")
end

function ListGlobalBloxScripts()
	local result = {}
	local script_service = game:GetService("ServerScriptService")
	local children = script_service:GetChildren()
	for _, child: Instance in ipairs(children) do
		if is_blox_script(child.Name) then
			table.insert(result, child.Name)
		end
	end
	return {
		items=result
	}
end

local max_depth = 2

function RecursiveListEverything(children: Array, instance: Instance, depth: number)
	if depth > max_depth then
		return
	end
	for _, child: Instance in ipairs(instance:GetChildren()) do
		local child_node = {
			text=child.Name,
			type=child.ClassName
		}
		local grand_children = child:GetChildren()
		if #grand_children > 0 then
			child_node.children = {}
			RecursiveListEverything(child_node.children, child, depth + 1)
		end
		table.insert(children, child_node)
	end
end

function ListEverything()
	local everything = {}
	local workspace_children = {}
	RecursiveListEverything(workspace_children, game.Workspace, 1)
	table.insert(everything, {
		text="Workspace",
		type=game.Workspace.ClassName,
		children=workspace_children
	})
	return {
		items=everything
	}
end

function GetGlobalBloxScript(name: string)
	local result = ""
	if is_blox_script(name) then
		local script_service = game:GetService("ServerScriptService")
		local script = script_service:FindFirstChild(name)
		if script:IsA("StringValue") then
			result = script.Value
		end
	end
	return {
		result=result,
		name=name,
	}
end

function SetGlobalBloxScript(name: string, value: string)
	if is_blox_script(name) then
		print("Setting global blox script " .. name)
		local script_service = game:GetService("ServerScriptService")
		local script = script_service:FindFirstChild(name)
		if not script then
			script = Instance.new("StringValue", script_service)
			script.Name = name
		elseif not script:IsA("StringValue") then
			script:Destroy()
			script = Instance.new("StringValue", script_service)
		end
		script.Value = value
	end
end

function DeleteGlobalBloxScript(name: string)
	if not is_blox_script(name) then
		return
	end
	print("DeleteGlobalBloxScript " .. name)
	local script_service = game:GetService("ServerScriptService")
	local blox_script = script_service:FindFirstChild(name)
	blox_script:Destroy()

	SendMessage("blox", "GlobalBloxScriptDeleted", {name=name})
end

function DeleteGlobalLuaScript(name: string)
	if is_blox_script(name) then
		return
	end
	print("DeleteGlobalLuaScript " .. name)
	local script_service = game:GetService("ServerScriptService")
	local lua_script = script_service:FindFirstChild(name)
	lua_script:Destroy()
end

function SetGlobalLuaScript(name: string, value: string)
	if is_blox_script(name) then
		return
	end
	print("Setting global lua script " .. name)
	local script_service = game:GetService("ServerScriptService")
	local script = script_service:FindFirstChild(name)
	if not script then
		script = Instance.new("Script", script_service)
		script.Name = name
	elseif not script:IsA("Script") then
		script:Destroy()
		script = Instance.new("Script", script_service)
		script.Name = name
	end
	script.Source = value
end

function SendMessage(queueName: string, event_type: string, event_data: any)
	local connectionInfo = GetConnectionInfo()
	local queue = connectionInfo.queues[queueName]
	local url = backend_url .. "/messages/" .. queue
	HttpService:PostAsync(url, HttpService:JSONEncode({
		event_type=event_type,
		event_data=event_data,
	}), "ApplicationJson", false, {
		authcode=connectionInfo.auth_code
	})
end

function GetMessages(queueName: string)
	local connectionInfo = GetConnectionInfo()
	local queue = connectionInfo.queues[queueName]
	local url = backend_url .. "/messages/" .. queue
	local response = HttpService:GetAsync(url, false, {
		authcode=connectionInfo.auth_code,
	})
	return HttpService:JSONDecode(response)
end

function killPreviousPlugin()
	local connectionInfo = GetConnectionInfo()
	local lastBloxUpdate = GetLastBloxUpdate()
	if connectionInfo == nil or os.time() - lastBloxUpdate > 50 then
		return true
	end
	local success = false
	pcall(function ()
		SendMessage("studio", {
			event_type="kill"
		})
		-- HttpService:PostAsync("http://localhost:9080/messages/studio", HttpService:JSONEncode({
		-- 	event_type="kill",
		-- }))
		success = true
	end)
	if not success then
		return success
	end

	wait(5)
	-- drain the queue if no previous plugin was running
	-- local resp = HttpService:GetAsync("http://localhost:9080/messages/studio")
	local resp = GetMessages("studio")
	print(resp)
	return success
end



function GetConnectionInfo()
	local serverStorage = game:GetService("ReplicatedStorage")
	local connectionString: StringValue = serverStorage:FindFirstChild("connection.info")
	if connectionString == nil then
		return nil
	end
	return HttpService:JSONDecode(connectionString.Value)
end

function SaveConnectionInfo(connectionInfo)
	local serverStorage = game:GetService("ReplicatedStorage")
	local connectionString: StringValue = serverStorage:FindFirstChild("connection.info")
	if connectionString == nil then
		connectionString = Instance.new("StringValue", serverStorage)
		connectionString.Name = "connection.info"
	end
	connectionString.Value = HttpService:JSONEncode(connectionInfo)
end

function GetLastBloxUpdate()
	local serverStorage = game:GetService("ReplicatedStorage")
	local lastUpdateValue: NumberValue = serverStorage:FindFirstChild("lastBloxUpdate")
	if lastUpdateValue == nil then
		return 0
	end
	return lastUpdateValue.Value
end

function SaveLastBloxUpdate()
	local serverStorage = game:GetService("ReplicatedStorage")
	local lastUpdateValue: NumberValue = serverStorage:FindFirstChild("lastBloxUpdate")
	if lastUpdateValue == nil then
		lastUpdateValue = Instance.new("NumberValue", serverStorage)
		lastUpdateValue.Name = "lastBloxUpdate"
	end
	lastUpdateValue.Value = os.time()
end

function ClearLastBloxUpdate()
	local serverStorage = game:GetService("ReplicatedStorage")
	local lastUpdateValue: NumberValue = serverStorage:FindFirstChild("lastBloxUpdate")
	if lastUpdateValue == nil then
		lastUpdateValue = Instance.new("NumberValue", serverStorage)
		lastUpdateValue.Name = "lastBloxUpdate"
	end
	lastUpdateValue.Value = 0
end

function CreateConnectionInfo()
	local response = HttpService:PostAsync(
		"https://7iokpqos42.execute-api.us-west-2.amazonaws.com/prod/codes",
		HttpService:JSONEncode({
			queueNames={"blox", "studio"}
		})
	)
	return HttpService:JSONDecode(response)
end

function RenewConnectionInfo(code: string)
	pcall(function()
		HttpService:RequestAsync({
			Url=backend_url .. "/codes/" .. code,
			Method="PUT"
		})
	end)
end

function SetupGui()
	local starterGui = game:GetService("StarterGui")
	local screen = starterGui:FindFirstChild("screen")
	if screen ~= nil then
		screen:Destroy()
	end
	screen = Instance.new("ScreenGui", starterGui)
	screen.Name = "screen"
	local label = Instance.new("TextLabel", screen)
	label.Name = "prompt"
	label.Text = ""
	label.Visible = false
	label.Position = UDim2.new(0.2, 0, 0.25, 0)
	label.Size = UDim2.new(0.6, 0, 0.5, 0)

	-- Show prompt when connection info is present and last update is 0
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local lastUpdate: NumberValue = replicatedStorage:WaitForChild("lastBloxUpdate")
	local connectionInfo: StringValue = replicatedStorage:WaitForChild("connection.info")

	function UpdatePrompt()
		label.Visible = lastUpdate.Value == 0
		if label.Visible then
			local info = HttpService:JSONDecode(connectionInfo.Value)
			label.Text = "BloxCode\nPlease navigate to www.bloxcode.studio and enter this code:\n" .. info.code
		end
	end
	UpdatePrompt()

	lastUpdate.Changed:Connect(UpdatePrompt)
	connectionInfo.Changed:Connect(UpdatePrompt)

	print("GUI updated")
end

function Sync()
	print("Sync script starting up")

	-- If we are starting back up after starting or stopping test,
	-- we can reuse the connection info. Check last update time from
	-- bloxcode studio to see if a new connection should be made.
	print("Get connection info")
	local connectionInfo = GetConnectionInfo()
	print(connectionInfo)
	local lastBloxUpdate = GetLastBloxUpdate()
	print(lastBloxUpdate)
	if connectionInfo == nil or os.time() - lastBloxUpdate > 20 then
		ClearLastBloxUpdate()
		connectionInfo = CreateConnectionInfo()
		print("Created connection info:")
		print(connectionInfo)
		SaveConnectionInfo(connectionInfo)
	end

	local running = 1
	while running
	do
		-- local response
		local data
		pcall(function ()

			-- renew connection if client hasn't connected yet
			lastBloxUpdate = GetLastBloxUpdate()
			if lastBloxUpdate == 0 then
				RenewConnectionInfo(connectionInfo.code)
			elseif os.time() - lastBloxUpdate > 20 then
				print("Client disconnected")
				connectionInfo = CreateConnectionInfo()
				SaveConnectionInfo(connectionInfo)
				ClearLastBloxUpdate()
			end
			data = GetMessages("studio")
			for _, message in ipairs(data.messages) do
				SaveLastBloxUpdate()
				-- print(start_time)
				print(message.event_type)
				if message.event_type == "ping" then
					-- print("Responding to ping")
					SendMessage("blox", "pong", nil)
				elseif message.event_type == "kill" then
					print("Sync script shutting down")
					running = 0
				elseif message.event_type == "ListGlobalBloxScripts" then
					local resp = ListGlobalBloxScripts()
					SendMessage("blox", "GlobalBloxScripts", resp)
				elseif message.event_type == "GetGlobalBloxScript" then
					if message.event_data and message.event_data.name then
						local resp = GetGlobalBloxScript(message.event_data.name)
						SendMessage("blox", "GlobalBloxScript", resp)
					end
				elseif message.event_type == "SetGlobalBloxScript" then
					if message.event_data and message.event_data.name and message.event_data.value then
						SetGlobalBloxScript(message.event_data.name, message.event_data.value)
					end
				elseif message.event_type == "SetGlobalLuaScript" then
					if message.event_data and message.event_data.name and message.event_data.value then
						SetGlobalLuaScript(message.event_data.name, message.event_data.value)
					end
				elseif message.event_type == "CreateGlobalBloxScript" then
					if message.event_data and message.event_data.name then
						SetGlobalBloxScript(message.event_data.name, "")
						SendMessage("blox", "GlobalBloxScriptCreated", {
							name=message.event_data.name
						})
					end
				elseif message.event_type == "DeleteGlobalBloxScript" then
					if message.event_data and message.event_data.name then
						DeleteGlobalBloxScript(message.event_data.name)
					end
				elseif message.event_type == "DeleteGlobalLuaScript" then
					if message.event_data and message.event_data.name then
						DeleteGlobalLuaScript(message.event_data.name)
					end
				elseif message.event_type == "ListEverything" then
					local result = ListEverything()
					SendMessage("blox", "ListEverythingResult", result)
					print("Replied with ListEverythingResult")
				end
			end
		end)
		wait(1)
	end
end

if killPreviousPlugin() then
	spawn(Sync)
	SetupGui()
end
