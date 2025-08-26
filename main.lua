local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local targetDistance = 5 -- 5 metrów w poziomie XZ
local npcNames = {"Military Scout", "Vulture Scout", "Rebel Scout", "Broker"}

local npcList = {} -- lista NPC

-- Sprawdza czy model jest celem
local function isTarget(model)
    for _, name in ipairs(npcNames) do
        if model.Name == name then
            return true
        end
    end
    return false
end

-- Dodaje podświetlenie NPC
local function highlightNPC(npc)
    if not npc:FindFirstChildOfClass("Highlight") then
        local highlight = Instance.new("Highlight")
        highlight.Parent = npc
        highlight.FillColor = Color3.fromRGB(255, 0, 0)
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.5
    end
end

-- Usuwa podświetlenie NPC
local function removeHighlight(npc)
    local hl = npc:FindFirstChildOfClass("Highlight")
    if hl then hl:Destroy() end
end

-- Tworzy nowoczesny pasek zdrowia nad NPC
local function createHealthBar(npc)
    if npc:FindFirstChild("HealthBarGui") then return end
    local head = npc:FindFirstChild("Head")
    if not head then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "HealthBarGui"
    billboard.Adornee = head
    billboard.Size = UDim2.new(4, 0, 0.5, 0)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true

    local background = Instance.new("Frame")
    background.BackgroundColor3 = Color3.fromRGB(50,50,50)
    background.Size = UDim2.new(1,0,1,0)
    background.BorderSizePixel = 0
    background.Parent = billboard

    local healthBar = Instance.new("Frame")
    healthBar.Name = "Bar"
    healthBar.BackgroundColor3 = Color3.fromRGB(0,255,0)
    healthBar.BorderSizePixel = 0
    healthBar.Size = UDim2.new(1,0,1,0)
    healthBar.Parent = background

    billboard.Parent = npc

    local humanoid = npc:FindFirstChild("Humanoid")
    if humanoid then
        humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
            healthBar:TweenSize(UDim2.new(ratio,0,1,0), "Out", "Quad", 0.2, true)
        end)
    end
end

-- Rekurencyjne skanowanie folderów w workspace
local function scanFolder(folder)
    local list = {}
    for _, child in pairs(folder:GetChildren()) do
        if child:IsA("Model") and isTarget(child) and child:FindFirstChild("HumanoidRootPart") and child:FindFirstChild("Humanoid") then
            if child.Humanoid.Health > 0 then
                highlightNPC(child)
                createHealthBar(child)
                table.insert(list, child)
            else
                removeHighlight(child)
            end
        end
        if #child:GetChildren() > 0 then
            local sublist = scanFolder(child)
            for _, v in pairs(sublist) do
                table.insert(list, v)
            end
        end
    end
    return list
end

-- Odświeżanie listy NPC co 1 sekundę
task.spawn(function()
    while true do
        npcList = scanFolder(workspace)
        task.wait(1)
    end
end)

-- Znajdź najbliższego NPC w zasięgu (poziom XZ) i w linii wzroku
local function getClosestTarget()
    local char = player.Character
    if not char or not char:FindFirstChild("Head") then return nil end
    local headPos = char.Head.Position

    local closest, closestDist = nil, targetDistance

    for _, npc in ipairs(npcList) do
        if npc:FindFirstChild("Humanoid") and npc.Humanoid.Health > 0 then
            local aimPart = npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart")
            if aimPart then
                local npcPosXZ = Vector3.new(aimPart.Position.X, 0, aimPart.Position.Z)
                local headPosXZ = Vector3.new(headPos.X, 0, headPos.Z)
                local dist = (npcPosXZ - headPosXZ).Magnitude

                if dist <= targetDistance then
                    local rayDir = aimPart.Position - headPos
                    local rayParams = RaycastParams.new()
                    rayParams.FilterDescendantsInstances = {char, npc}
                    rayParams.FilterType = Enum.RaycastFilterType.Blacklist

                    local result = workspace:Raycast(headPos, rayDir, rayParams)
                    if result then
                        if not result.Instance:IsDescendantOf(npc) then
                            continue
                        end
                    end

                    if dist < closestDist then
                        closest, closestDist = npc, dist
                    end
                end
            end
        else
            removeHighlight(npc)
        end
    end

    return closest
end

-- Lock-on kamery
RunService.RenderStepped:Connect(function()
    local target = getClosestTarget()
    if target then
        local aimPart = target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart")
        if aimPart then
            camera.CFrame = CFrame.new(camera.CFrame.Position, aimPart.Position)
        end
    end
end)
