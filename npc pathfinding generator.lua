-- ServerScriptService, Server Sided
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")
local remoteEvent = Instance.new("RemoteEvent")
remoteEvent.Parent = game.ReplicatedStorage

-- Calculate NPC movement using PathfindingService to generate NPC Humanoid movement position
local function pathfindingMovement(bPos,npcTable,playerFolder)
	local totalNPC = #npcTable;
	local x,z = 0,0; local countedNPCs = 0
	local pathTables = {}; local failedNPCPathfinding = {}
	
	if playerFolder ~= nil then
		for _,npcs in pairs(npcTable) do
			local npcObject = playerFolder[npcs]
			
			if playerFolder ~= nil and npcObject ~= nil then
				local p = pcall(function()
					task.delay(0, function()					
						if npcObject.Humanoid:GetAttribute("pathPlaying") == true then
							npcObject.Humanoid:SetAttribute("pathPlaying", false)
						else
							npcObject.Humanoid:SetAttribute("pathPlaying", true)
							print("Moving")

							local pathcFrames = bPos * CFrame.new(x,0,z)
							local path = PathfindingService:CreatePath()

							path:ComputeAsync(npcObject.HumanoidRootPart.Position, pathcFrames.Position)
							local totalPath = #path:GetWaypoints();

							if totalPath >= 1 then
								table.insert(pathTables, path:GetWaypoints())
								for _,g in pairs(path:GetWaypoints()) do
									if npcObject.Humanoid:GetAttribute("pathPlaying") == true then
										npcObject.Humanoid:MoveTo(g.Position); npcObject.Humanoid.MoveToFinished:Wait()
									else
										break
									end
								end

								npcObject.Humanoid:SetAttribute("pathPlaying", false)
							else
								table.insert(failedNPCPathfinding, npcObject.Humanoid)
							end
						end
					end)	

					if countedNPCs >= 5 then
						countedNPCs = 0; x = x+4.5; z = 0
					end;

					countedNPCs = countedNPCs +1
					z = z +3; task.wait(0.1)
				end)
			else
				break
			end
		end
		
		-- Moving with past working Pathfinding result, when the NPC PathfindingService failed to calculate
		if #pathTables >= 1 then
			for _,failedNPC in pairs(failedNPCPathfinding) do
				task.delay(0, function()
					failedNPC:SetAttribute("pathPlaying", true)

					for x,Path in pairs(pathTables[math.random(1,#pathTables)]) do
						if x >= 2 then
							failedNPC:MoveTo(Path.Position); failedNPC.MoveToFinished:Wait()
						end
					end

					failedNPC:SetAttribute("pathPlaying", false)
				end)

				task.wait(0.1)
			end
		end
	end
end

-- Player added function
local function playerAdded(plr)
	task.delay(0, function()
		local plrFolder = Instance.new("Folder")
		plrFolder.Name = `{plr.Name}_Folder`; plrFolder.Parent = workspace
		
		-- Generating NPC from Player Avatar description
		task.delay(0, function()
			local npcTable = {}
			local x,z = 0,0; local npcSpawned = 0
			local avatarDescription = game.Players:GetHumanoidDescriptionFromUserId(plr.UserId)
			local plrNPC = game.Players:CreateHumanoidModelFromDescription(avatarDescription, Enum.HumanoidRigType.R15)
			for _,v in pairs(plrNPC:GetChildren()) do
				if v:IsA("Accessory") then
					v:FindFirstChildOfClass("MeshPart").CanQuery = false
				end
			end
			
			for _ = 1,10 do
				local Highlight = Instance.new("Highlight")

				Highlight.Enabled = false
				Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
				Highlight.FillColor = Color3.new(1, 1, 1)
				Highlight.FillTransparency = 0.7

				Highlight.OutlineColor = Color3.new(0, 0, 0)
				Highlight.OutlineTransparency = 0

				local plrNPC = plrNPC:Clone(); table.insert(npcTable, plrNPC)
				plrNPC.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				plrNPC.Name = HttpService:GenerateGUID(false); plrNPC.Parent = plrFolder
				plrNPC.HumanoidRootPart.CFrame = plrNPC.HumanoidRootPart.CFrame * CFrame.new(x,0,z)
				Highlight.Parent = plrNPC; plrNPC.Humanoid:SetAttribute("pathPlaying", false)

				npcSpawned = npcSpawned +1; z = z +3

				if npcSpawned >= 5 then
					npcSpawned = 0; x = x+4.5; z = 0
				end

				local idleAnimation = plrNPC.Humanoid:LoadAnimation(plrNPC.Animate.idle:FindFirstChildOfClass("Animation"))
				local runAnimation = plrNPC.Humanoid:LoadAnimation(plrNPC.Animate.run:FindFirstChildOfClass("Animation"))
				local fixedBools = false

				plrNPC.Humanoid.Running:Connect(function(s)
					if s >= 1 then
						if fixedBools == false then
							runAnimation:Play(); idleAnimation:Stop()								
						end; fixedBools = true
					else
						fixedBools = false
						runAnimation:Stop(); idleAnimation:Play()
					end
				end)
				
				plrNPC.Humanoid:GetAttributeChangedSignal("pathPlaying"):Connect(function()
					if script:GetAttribute("pathPlaying") == false then
						plrNPC.Humanoid:MoveTo(plrNPC.HumanoidRootPart.Position)
					end
				end)
			end
						
			for _,humanoidBasePart in pairs(npcTable) do
				for g,basePart in pairs(humanoidBasePart:GetChildren()) do
					if basePart:IsA("BasePart") then
						basePart.CollisionGroup = "NPC"; basePart:SetNetworkOwner(nil)
					end
				end
			end
		end)
		
		-- Repeating check of Player Humanoid & HumanoidRootPart if it's existed in workspace, stopped until it's exist
		local function checkCharacterExist()
			task.delay(0, function()
				for i = 1,120 do
					local characterAttribute = plr:GetAttribute("serverCharacterLoaded")
					
					if characterAttribute == nil or characterAttribute == false then
						local rootPart, humanoidObj = nil, nil
						local p = pcall(function()
							rootPart = workspace[plr.Name].HumanoidRootPart
							humanoidObj = workspace[plr.Name].Humanoid
						end)

						if p == true and rootPart ~= nil and humanoidObj ~= nil and humanoidObj.Health >= 1 then
							plr:SetAttribute("serverCharacterLoaded", true); print(plr.Name, "character loaded from server")
							
							humanoidObj.Died:Once(function()
								plr:SetAttribute("serverCharacterLoaded", false)
							end)
							break
						end
					else
						print(plr.Name, "character already loaded"); break
					end
					task.wait(1)
				end
			end)
		end
		
		checkCharacterExist()
		plr.CharacterAdded:Connect(function()
			checkCharacterExist()
		end)
	end)
end

game.Players.PlayerAdded:Connect(playerAdded)
-- Receiving client data through remote event
remoteEvent.OnServerEvent:Connect(function(Player,Response)
	if Response[1] == "npcMovement" then
		local mousePos = Response[2]; local npcGroupTable = Response[3]
		pathfindingMovement(Response[2], Response[3],workspace[Player.Name .. "_Folder"])
	end
end)

-- LocalScript, Client Sided
local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()

-- Used to check Character client and Character server till it load
repeat task.wait()
until game:IsLoaded() and Player:GetAttribute("serverCharacterLoaded") == true and Player.Character.Humanoid ~= nil
print("Server & Client loaded")

local buttonDowned = false
local playerFolder = workspace:FindFirstChild(`{Player.Name}_Folder`)
local clickedCount = 0; local selectedNPC = nil
local selectedTable = {}

-- The function that to select the NPC from single & group
local function selectNPC(npcObj, selectType)
	if playerFolder ~= nil then	
		if npcObj.Parent.Parent == playerFolder then	
			local saTable = {}; local npcObject = npcObj.Parent
			clickedCount = clickedCount +1;
			script:SetAttribute("buttonDown", true)
			
			if clickedCount == 1 then
				if npcObject.Highlight.Enabled == false then
					npcObject.Highlight.Enabled = true
				else
					npcObject.Highlight.Enabled = false
				end
			elseif clickedCount >= 2 and selectedNPC == npcObject then
				local highlightEnabled = npcObject.Highlight.Enabled
				
				for _,v in pairs(playerFolder:GetChildren()) do
					if highlightEnabled == true then
						v.Highlight.Enabled = true;
					else
						v.Highlight.Enabled = false
					end
				end
			end
			
			for _,npcs in pairs(playerFolder:GetChildren()) do
				if npcs.Highlight.Enabled == true then
					table.insert(saTable, npcs.Name)
				end
			end
			
			selectedTable = saTable; selectedNPC = npcObject
		else
			if #selectedTable >= 1 then
				-- firing Remote events, to make NPC moving from Mouse Position
				game.ReplicatedStorage.RemoteEvent:FireServer({"npcMovement",Mouse.Hit,selectedTable})
			end
		end
	else
		playerFolder = workspace:FindFirstChild(`{Player.Name}_Folder`)
	end
end

-- Trigger when client left clicking or touching screens
Mouse.Button1Down:Connect(function(hit)
	local mouseTarget = Mouse.Target
	
	if mouseTarget ~= nil then
		selectNPC(Mouse.Target);
	end
end)

-- buttonDown interval for double clicking, used for selecting all existing NPC
script:GetAttributeChangedSignal("buttonDown"):Connect(function()
	if script:GetAttribute("buttonDown") == true then
		task.wait(0.21); clickedCount = 0; script:SetAttribute("buttonDown", false)
	end
end)
