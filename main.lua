local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua"))()

-- NPC
local npcNames = {"Military Scout", "Vulture Scout", "Rebel Scout", "Broker", "Merchant"}
local npcList = {}

-- Opcje
local highlightNPCEnabled = false
local highlightPlayersEnabled = false
local autoAimlockEnabled = false
local keyAimlockActive = false
local aimSpeed = 0.2
local aimlockDistance = 500
local highlightDistance = 200
local highlightAutoRefresh = false
local highlightRefreshRate = 5
local aimlockTargetPart = "Head"

-- Odświeżanie listy NPC
local function refreshNPCList()
    npcList = {}
    local function scanFolder(folder)
        for _, child in pairs(folder:GetChildren()) do
            if child:IsA("Model") and child:FindFirstChild("HumanoidRootPart") and child:FindFirstChild("Humanoid") then
                for _, name in ipairs(npcNames) do
                    if child.Name == name then
                        table.insert(npcList, child)
                        break
                    end
                end
            end
            if #child:GetChildren() > 0 then
                scanFolder(child)
            end
        end
    end
    scanFolder(workspace)
end

-- Pobranie części docelowej do aimlock
local function getAimPart(model)
    local targetPartName = (type(aimlockTargetPart) == "string") and aimlockTargetPart or "Head"
    local priorities = {targetPartName, "HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso"}

    for _, partName in ipairs(priorities) do
        local part = model:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            return part
        end
    end

    for _, child in ipairs(model:GetDescendants()) do
        if child:IsA("BasePart") then
            return child
        end
    end
    return nil
end

-- Sprawdzenie czy część jest widoczna
local function isVisible(part)
    local origin = camera.CFrame.Position
    local direction = (part.Position - origin)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {player.Character}
    local ray = workspace:Raycast(origin, direction, rayParams)
    if ray then
        return ray.Instance:IsDescendantOf(part.Parent)
    end
    return true
end

-- Highlight NPC
local function updateNPCHighlights()
    if not player.Character or not player.Character:FindFirstChild("Head") then return end
    local headPos = player.Character.Head.Position
    for _, npc in ipairs(npcList) do
        local humanoid = npc:FindFirstChild("Humanoid")
        local part = getAimPart(npc)
        local hl = npc:FindFirstChild("NPCHighlight")
        if humanoid and humanoid.Health > 0 and part then
            local dist = (part.Position - headPos).Magnitude
            if highlightNPCEnabled and dist <= highlightDistance then
                if not hl then
                    hl = Instance.new("Highlight")
                    hl.Name = "NPCHighlight"
                    hl.Parent = npc
                    if npc.Name == "Merchant" then
                        hl.FillColor = Color3.fromRGB(0, 255, 0)
                    elseif npc.Name == "Broker" then
                        hl.FillColor = Color3.fromRGB(255, 165, 0)
                    else
                        hl.FillColor = Color3.fromRGB(255, 0, 0)
                    end
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.FillTransparency = 0.5
                end
            elseif hl then
                hl:Destroy()
            end
        elseif hl then
            hl:Destroy()
        end
    end
end

-- Highlight graczy
local function updatePlayerHighlights()
    if not player.Character or not player.Character:FindFirstChild("Head") then return end
    local headPos = player.Character.Head.Position
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local humanoid = p.Character:FindFirstChild("Humanoid")
            local part = getAimPart(p.Character)
            local hl = p.Character:FindFirstChild("PlayerHighlight")
            if humanoid and humanoid.Health > 0 and part then
                local dist = (part.Position - headPos).Magnitude
                if highlightPlayersEnabled and dist <= highlightDistance then
                    if not hl then
                        hl = Instance.new("Highlight")
                        hl.Name = "PlayerHighlight"
                        hl.Parent = p.Character
                        hl.FillColor = Color3.fromRGB(128, 0, 128)
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.FillTransparency = 0.5
                    end
                elseif hl then
                    hl:Destroy()
                end
            elseif hl then
                hl:Destroy()
            end
        end
    end
end

-- Aimlock
local function getClosestHumanoid()
    if not player.Character or not player.Character:FindFirstChild("Head") then return nil end
    local headPos = player.Character.Head.Position
    local closest, closestDist = nil, aimlockDistance

    local allHumanoids = {}
    for _, npc in ipairs(npcList) do table.insert(allHumanoids, npc) end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            table.insert(allHumanoids, p.Character)
        end
    end

    for _, model in ipairs(allHumanoids) do
        local humanoid = model:FindFirstChild("Humanoid")
        local part = getAimPart(model)
        if humanoid and humanoid.Health > 0 and part and isVisible(part) then
            local dist = (part.Position - headPos).Magnitude
            if dist < closestDist then
                closest, closestDist = model, dist
            end
        end
    end
    return closest
end

-- Toggle pod P
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.P then
        keyAimlockActive = not keyAimlockActive
    end
end)

-- Funkcje natychmiastowego update
local function immediateUpdateHighlights()
    if highlightNPCEnabled then
        refreshNPCList()
        updateNPCHighlights()
    else
        for _, npc in ipairs(npcList) do
            local hl = npc:FindFirstChild("NPCHighlight")
            if hl then hl:Destroy() end
        end
    end

    if highlightPlayersEnabled then
        updatePlayerHighlights()
    else
        for _, p in ipairs(Players:GetPlayers()) do
            local hl = p.Character and p.Character:FindFirstChild("PlayerHighlight")
            if hl then hl:Destroy() end
        end
    end
end

-- Pętle do ciągłego aimlocka i highlightów
RunService.RenderStepped:Connect(function()
    if highlightNPCEnabled then updateNPCHighlights() end
    if highlightPlayersEnabled then updatePlayerHighlights() end

    if autoAimlockEnabled or keyAimlockActive then
        local target = getClosestHumanoid()
        if target then
            local part = getAimPart(target)
            if part then
                camera.CFrame = camera.CFrame:Lerp(CFrame.new(camera.CFrame.Position, part.Position), aimSpeed)
            end
        end
    end
end)

-- Automatyczne odświeżanie highlight
spawn(function()
    while true do
        if highlightAutoRefresh then
            immediateUpdateHighlights()
        end
        wait(highlightRefreshRate)
    end
end)

--== GUI Rayfield ==
local Window = Rayfield:CreateWindow({
    Name = "Aimlock Hub",
    LoadingTitle = "Ładowanie...",
    LoadingSubtitle = "Proszę czekać",
    Theme = "Dark",
    ToggleKey = Enum.KeyCode.RightControl
})

local Tab = Window:CreateTab("Ustawienia", 4483362458)

-- Highlight NPC
Tab:CreateToggle({
    Name = "Highlight NPC",
    CurrentValue = highlightNPCEnabled,
    Flag = "highlightNPCToggle",
    Callback = function(value)
        highlightNPCEnabled = value
        immediateUpdateHighlights()
    end
})

-- Highlight Players
Tab:CreateToggle({
    Name = "Highlight Players",
    CurrentValue = highlightPlayersEnabled,
    Flag = "highlightPlayersToggle",
    Callback = function(value)
        highlightPlayersEnabled = value
        immediateUpdateHighlights()
    end
})

-- Auto Aimlock
Tab:CreateToggle({
    Name = "Auto Aimlock",
    CurrentValue = autoAimlockEnabled,
    Flag = "autoAimlockToggle",
    Callback = function(value)
        autoAimlockEnabled = value
    end
})

-- Aimlock pod P
Tab:CreateToggle({
    Name = "Aimlock pod P",
    CurrentValue = keyAimlockActive,
    Flag = "keyAimlockToggle",
    Callback = function(value)
        keyAimlockActive = value
    end
})

-- Auto Refresh Highlight
Tab:CreateToggle({
    Name = "Auto Refresh Highlight",
    CurrentValue = highlightAutoRefresh,
    Flag = "highlightAutoRefresh",
    Callback = function(value)
        highlightAutoRefresh = value
    end
})

-- Highlight Refresh Rate
Tab:CreateSlider({
    Name = "Highlight Refresh Rate",
    Range = {1,60},
    Increment = 1,
    CurrentValue = highlightRefreshRate,
    Suffix = " sec",
    Flag = "highlightRefreshRate",
    Callback = function(value)
        highlightRefreshRate = value
    end
})

-- Smoothness
Tab:CreateSlider({
    Name = "Smoothness",
    Range = {0.01,1},
    Increment = 0.01,
    CurrentValue = aimSpeed,
    Suffix = "",
    Flag = "aimSpeedSlider",
    Callback = function(value)
        aimSpeed = value
    end
})

-- Aimlock Distance
Tab:CreateSlider({
    Name = "Aimlock Distance",
    Range = {5,2000},
    Increment = 5,
    CurrentValue = aimlockDistance,
    Suffix = " stud",
    Flag = "aimDistanceSlider",
    Callback = function(value)
        aimlockDistance = value
    end
})

-- Highlight Distance
Tab:CreateSlider({
    Name = "Highlight Distance",
    Range = {5,2000},
    Increment = 5,
    CurrentValue = highlightDistance,
    Suffix = " stud",
    Flag = "highlightDistanceSlider",
    Callback = function(value)
        highlightDistance = value
    end
})

-- Wybór części ciała do aimlock
local bodyParts = {"Head", "HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso"}
Tab:CreateDropdown({
    Name = "Aimlock Target Part",
    Options = bodyParts,
    CurrentOption = aimlockTargetPart,
    Flag = "aimlockPartDropdown",
    Callback = function(option)
        aimlockTargetPart = option
        -- natychmiast aktualizujemy aimlock target
        if autoAimlockEnabled or keyAimlockActive then
            local target = getClosestHumanoid()
            if target then
                local part = getAimPart(target)
                if part then
                    camera.CFrame = CFrame.new(camera.CFrame.Position, part.Position)
                end
            end
        end
    end
})
