-- 🔴 Red Scripts v1.0 for Steal a Brainrot (Delta Executor)
-- Features: Auto Collect Cash (toggle), Steal Best Brainrot from Target (TP > Steal > TP Back + Collect)
-- Mobile-Friendly | Red Theme GUI | Paste into Delta > Execute

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Require Game Datas
local Animals = require(ReplicatedStorage.Datas.Animals)
local Mutations = require(ReplicatedStorage.Datas.Mutations)

-- Variables
local ownPlot = nil
local autoCollectEnabled = false
local collectConnection = nil
local noclipConnection = nil
local flying = false
local flyConnection = nil
local noclipEnabled = false

-- Find Own Plot
local function findOwnPlot()
    for _, plot in pairs(Workspace.Plots:GetChildren()) do
        if plot:FindFirstChild("PlotSign") and plot.PlotSign:FindFirstChild("YourBase") and plot.PlotSign.YourBase.Enabled then
            return plot
        end
    end
    return nil
end

ownPlot = findOwnPlot()

-- Apply Mutation
local function applyMutation(data, mutationName)
    if Mutations[mutationName] then
        local modifier = Mutations[mutationName].Modifier
        data.Price = data.Price * (1 + modifier)
        data.Generation = data.Generation * (1 + modifier)
    end
end

-- Get Brainrot Data from Podium
local function getBrainrotData(plot, podiumIndex)
    local podium = plot.AnimalPodiums:FindFirstChild(tostring(podiumIndex))
    if not podium then return nil end
    local spawn = podium.Base.Spawn
    local attachment = spawn:FindFirstChild("Attachment")
    if not attachment then return nil end
    local billboard = attachment:FindFirstChild("AnimalOverhead")
    if not billboard or not billboard.DisplayName.Visible then return nil end
    local displayName = billboard.DisplayName.Text
    local data = table.clone(Animals[displayName] or {})
    local mutationLabel = billboard:FindFirstChild("Mutation")
    if mutationLabel and mutationLabel.Visible then
        local mutation = mutationLabel.Text
        data.Mutation = mutation
        applyMutation(data, mutation)
    end
    return data
end

-- Is Plot Open (all lasers down)
local function isPlotOpen(plot)
    if not plot:FindFirstChild("LaserHitbox") then return false end
    for _, laser in pairs(plot.LaserHitbox:GetChildren()) do
        if laser:IsA("BasePart") and laser.CanCollide then
            return false
        end
    end
    return true
end

-- Collect All Cash in Own Plot
local function collectCash()
    if not ownPlot then return end
    for _, obj in pairs(ownPlot:GetDescendants()) do
        if (obj:IsA("ClickDetector") or obj:IsA("ProximityPrompt")) and (obj.Name:lower():find("cash") or obj.Parent.Name:lower():find("cash") or obj.Name:lower():find("collect") or obj.Parent.Name:lower():find("collect")) then
            if obj:IsA("ClickDetector") then
                fireclickdetector(obj)
            elseif obj:IsA("ProximityPrompt") then
                fireproximityprompt(obj)
            end
        end
    end
end

-- Toggle Auto Collect
local function toggleAutoCollect()
    autoCollectEnabled = not autoCollectEnabled
    if autoCollectEnabled then
        collectConnection = RunService.Heartbeat:Connect(function()
            collectCash()
        end)
    else
        if collectConnection then collectConnection:Disconnect() end
    end
end

-- Toggle Noclip
local function toggleNoclip(enabled)
    noclipEnabled = enabled
    if enabled then
        noclipConnection = RunService.Stepped:Connect(function()
            if player.Character then
                for _, part in pairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if noclipConnection then noclipConnection:Disconnect() end
    end
end

-- Fly Function (Mobile/PC)
local function toggleFly(enabled)
    flying = enabled
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local root = char.HumanoidRootPart
    if enabled then
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(4000, 4000, 4000)
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent = root
        flyConnection = RunService.Heartbeat:Connect(function()
            if flying then
                local move = Vector3.new(0, 0, 0)
                local cam = camera.CFrame
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cam.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cam.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cam.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cam.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end
                bv.Velocity = move.Unit * 50
            end
        end)
    else
        if flyConnection then flyConnection:Disconnect() end
        if root:FindFirstChild("BodyVelocity") then root.BodyVelocity:Destroy() end
    end
end

-- Steal Best from Target
local function stealFromTarget(targetName)
    local targetPlayer = Players:FindFirstChild(targetName)
    if not targetPlayer then return false, "Player not found" end
    local targetPlot = Workspace.Plots:FindFirstChild(targetPlayer.Name)
    if not targetPlot then return false, "No plot found" end
    if not isPlotOpen(targetPlot) then return false, "Plot locked" end

    -- Find Best Brainrot (highest Price)
    local bestData = nil
    local bestPodium = nil
    local bestIndex = nil
    for _, podiumName in pairs(targetPlot.AnimalPodiums:GetChildren()) do
        local index = tonumber(podiumName.Name)
        if index then
            local data = getBrainrotData(targetPlot, index)
            if data and (not bestData or data.Price > bestData.Price) then
                bestData = data
                bestPodium = podiumName
                bestIndex = index
            end
        end
    end
    if not bestPodium then return false, "No brainrots found" end

    -- Save Pos & Enable Noclip/Fly
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return false, "No character" end
    local root = char.HumanoidRootPart
    local saveCFrame = root.CFrame
    toggleNoclip(true)
    toggleFly(true)

    -- TP to Best Brainrot
    local spawnPos = bestPodium.Base.Spawn.CFrame * CFrame.new(0, 5, -10)
    root.CFrame = spawnPos

    wait(0.5)

    -- Fire Steal Prompt
    local prompt = bestPodium:FindFirstChild("ProximityPrompt", true) or bestPodium.Base:FindFirstChild("ProximityPrompt") or bestPodium.Base.Spawn:FindFirstChild("ProximityPrompt")
    if prompt then
        fireproximityprompt(prompt)
    else
        -- Fallback: fireclick if detector
        local detector = bestPodium:FindFirstChild("ClickDetector", true)
        if detector then fireclickdetector(detector) end
    end

    wait(1)

    -- TP Back & Collect
    root.CFrame = saveCFrame
    collectCash()

    -- Disable Fly/Noclip
    toggleFly(false)
    toggleNoclip(false)

    return true, "Stolen: " .. (bestData.Name or "Unknown") .. " (Value: " .. math.floor(bestData.Price) .. ")"
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "RedScripts"
gui.Parent = player:WaitForChild("PlayerGui")
gui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 380, 0, 500)
mainFrame.Position = UDim2.new(0.5, -190, 0.5, -250)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
title.BorderSizePixel = 0
title.Text = "🔴 Red Scripts v1.0"
title.TextColor3 = Color3.new(1,1,1)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = title
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

local function createToggle(name, posY, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 45)
    frame.Position = UDim2.new(0, 10, 0, posY)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    frame.BorderSizePixel = 0
    frame.Parent = mainFrame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
    btn.Text = name .. ": OFF"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.Gotham
    btn.Parent = frame

    local toggled = false
    btn.MouseButton1Click:Connect(function()
        toggled = not toggled
        btn.Text = name .. ": " .. (toggled and "ON" or "OFF")
        btn.BackgroundColor3 = toggled and Color3.fromRGB(200, 0, 0) or Color3.fromRGB(100, 0, 0)
        callback(toggled)
    end)
end

local function createButton(name, posY, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 45)
    btn.Position = UDim2.new(0, 10, 0, posY)
    btn.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
    btn.Text = name
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.Parent = mainFrame
    btn.MouseButton1Click:Connect(callback)
end

-- Toggles
createToggle("Auto Collect Cash", 70, toggleAutoCollect)
createToggle("Fly", 130, toggleFly)
createToggle("Noclip", 190, toggleNoclip)

-- Target Input & Steal
local targetBox = Instance.new("TextBox")
targetBox.Size = UDim2.new(1, -20, 0, 40)
targetBox.Position = UDim2.new(0, 10, 0, 250)
targetBox.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
targetBox.Text = "Enter player name"
targetBox.TextColor3 = Color3.new(1,1,1)
targetBox.TextScaled = true
targetBox.Font = Enum.Font.Gotham
targetBox.Parent = mainFrame
targetBox.Focused:Connect(function() if targetBox.Text == "Enter player name" then targetBox.Text = "" end end)

createButton("🔴 Steal Best from Target", 300, function()
    local targetName = targetBox.Text
    if targetName == "" or targetName == "Enter player name" then return end
    spawn(function()
        local success, msg = stealFromTarget(targetName)
        -- Simple notify (can add GUI notify)
        print("Red Scripts: " .. (success and "SUCCESS: " or "FAIL: ") .. msg)
    end)
end)

-- Update ownPlot periodically
spawn(function()
    while gui.Parent do
        ownPlot = findOwnPlot()
        wait(5)
    end
end)

print("🔴 Red Scripts Loaded! Own Plot:", ownPlot and ownPlot.Name or "Not Found")
