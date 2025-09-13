local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LOCAL_PLAYER = Players.LocalPlayer

local ESPModule = {}

-- Storage for ESP objects
ESPModule.ESPObjects = {}

-- Utility functions (you can move these outside if you want to share)
local function Color3ToHex(color)
    return string.format("#%02X%02X%02X", 
        math.floor(color.R * 255), 
        math.floor(color.G * 255), 
        math.floor(color.B * 255))
end

local function HexToColor3(hex)
    if typeof(hex) == "Color3" then
        return hex
    end
    
    hex = tostring(hex):gsub("#", "")
    
    if #hex ~= 6 then
        return Color3.fromRGB(255, 255, 255)
    end
    
    return Color3.fromRGB(
        tonumber(hex:sub(1, 2), 16) or 255,
        tonumber(hex:sub(3, 4), 16) or 255,
        tonumber(hex:sub(5, 6), 16) or 255
    )
end

local function worldToViewportPoint(pos)
    return Camera:WorldToViewportPoint(pos)
end

local function createDrawing(type)
    return Drawing.new(type)
end

-- ESP Object Class
local ESPObject = {}
ESPObject.__index = ESPObject

function ESPObject.new(player)
    local self = setmetatable({}, ESPObject)
    self.Player = player
    self.Drawings = {}
    
    -- Create all drawings upfront
    self.Drawings.Box = createDrawing("Square")
    self.Drawings.Box.Thickness = 2
    self.Drawings.Box.Filled = false
    self.Drawings.Box.Color = HexToColor3(getgenv().Config.ESP.BoxColor)
    self.Drawings.Box.Transparency = 1
    self.Drawings.Box.Visible = false
    
    self.Drawings.Name = createDrawing("Text")
    self.Drawings.Name.Size = 16
    self.Drawings.Name.Center = true
    self.Drawings.Name.Outline = true
    self.Drawings.Name.Color = HexToColor3(getgenv().Config.ESP.NameColor)
    self.Drawings.Name.Transparency = 1
    self.Drawings.Name.Visible = false
    
    self.Drawings.Distance = createDrawing("Text")
    self.Drawings.Distance.Size = 14
    self.Drawings.Distance.Center = true
    self.Drawings.Distance.Outline = true
    self.Drawings.Distance.Color = HexToColor3(getgenv().Config.ESP.NameColor)
    self.Drawings.Distance.Transparency = 1
    self.Drawings.Distance.Visible = false
    
    self.Drawings.HealthBar = createDrawing("Square")
    self.Drawings.HealthBar.Thickness = 1
    self.Drawings.HealthBar.Filled = true
    self.Drawings.HealthBar.Color = HexToColor3(getgenv().Config.ESP.HealthColor)
    self.Drawings.HealthBar.Transparency = 1
    self.Drawings.HealthBar.Visible = false
    
    self.Drawings.HealthBarOutline = createDrawing("Square")
    self.Drawings.HealthBarOutline.Thickness = 1
    self.Drawings.HealthBarOutline.Filled = false
    self.Drawings.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
    self.Drawings.HealthBarOutline.Transparency = 1
    self.Drawings.HealthBarOutline.Visible = false
    
    self.Drawings.Tracer = createDrawing("Line")
    self.Drawings.Tracer.Thickness = 1
    self.Drawings.Tracer.Color = HexToColor3(getgenv().Config.ESP.TracerColor)
    self.Drawings.Tracer.Transparency = 1
    self.Drawings.Tracer.Visible = false
    
    return self
end

function ESPObject:SetVisible(visible)
    for _, drawing in pairs(self.Drawings) do
        if drawing then
            drawing.Visible = visible
        end
    end
end

function ESPObject:Remove()
    for _, drawing in pairs(self.Drawings) do
        if drawing then
            drawing:Remove()
        end
    end
    self.Drawings = {}
end

function ESPObject:Update()
    if not self.Player.Character or not self.Player.Character:FindFirstChild("HumanoidRootPart") then
        self:SetVisible(false)
        return
    end
    
    local character = self.Player.Character
    local humanoidRootPart = character.HumanoidRootPart
    local humanoid = character:FindFirstChild("Humanoid")
    
    if not humanoid then
        self:SetVisible(false)
        return
    end
    
    local distance = math.huge
    if LOCAL_PLAYER.Character and LOCAL_PLAYER.Character:FindFirstChild("HumanoidRootPart") then
        distance = (LOCAL_PLAYER.Character.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
    end
    
    if not getgenv().Config.ESP.Enabled or distance > getgenv().Config.ESP.MaxDistance then
        self:SetVisible(false)
        return
    end
    
    local cf = humanoidRootPart.CFrame
    local size = character:GetExtentsSize()
    
    local corners = {
        cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2),
        cf * CFrame.new(size.X/2, -size.Y/2, -size.Z/2),
        cf * CFrame.new(-size.X/2, size.Y/2, -size.Z/2),
        cf * CFrame.new(size.X/2, size.Y/2, -size.Z/2),
        cf * CFrame.new(-size.X/2, -size.Y/2, size.Z/2),
        cf * CFrame.new(size.X/2, -size.Y/2, size.Z/2),
        cf * CFrame.new(-size.X/2, size.Y/2, size.Z/2),
        cf * CFrame.new(size.X/2, size.Y/2, size.Z/2)
    }
    
    local min = Vector2.new(math.huge, math.huge)
    local max = Vector2.new(-math.huge, -math.huge)
    local visible = false
    
    for _, corner in pairs(corners) do
        local point, onScreen = worldToViewportPoint(corner.Position)
        if onScreen then
            visible = true
            min = Vector2.new(math.min(min.X, point.X), math.min(min.Y, point.Y))
            max = Vector2.new(math.max(max.X, point.X), math.max(max.Y, point.Y))
        end
    end
    
    if not visible then
        self:SetVisible(false)
        return
    end
    
    if min.X == math.huge then
        local screenPos, onScreen = worldToViewportPoint(humanoidRootPart.Position)
        if not onScreen then
            self:SetVisible(false)
            return
        end
        
        local fallbackSize = Vector2.new(size.X * 100 / distance * 50, size.Y * 100 / distance * 50)
        fallbackSize = Vector2.new(math.max(fallbackSize.X, 20), math.max(fallbackSize.Y, 30))
        min = Vector2.new(screenPos.X - fallbackSize.X/2, screenPos.Y - fallbackSize.Y/2)
        max = Vector2.new(screenPos.X + fallbackSize.X/2, screenPos.Y + fallbackSize.Y/2)
    end
    
    local boxSize = Vector2.new(max.X - min.X, max.Y - min.Y)
    
    -- Box
    if getgenv().Config.ESP.ShowBoxes then
        self.Drawings.Box.Size = boxSize
        self.Drawings.Box.Position = Vector2.new(min.X, min.Y)
        self.Drawings.Box.Color = HexToColor3(getgenv().Config.ESP.BoxColor)
        self.Drawings.Box.Visible = true
    else
        self.Drawings.Box.Visible = false
    end
    
    -- Name
    if getgenv().Config.ESP.ShowNames then
        self.Drawings.Name.Text = self.Player.Name
        self.Drawings.Name.Position = Vector2.new((min.X + max.X) / 2, min.Y - 20)
        self.Drawings.Name.Color = HexToColor3(getgenv().Config.ESP.NameColor)
        self.Drawings.Name.Visible = true
    else
        self.Drawings.Name.Visible = false
    end
    
    -- Distance
    if getgenv().Config.ESP.ShowDistance then
        self.Drawings.Distance.Text = string.format("%.0fm", distance)
        self.Drawings.Distance.Position = Vector2.new((min.X + max.X) / 2, max.Y + 5)
        self.Drawings.Distance.Color = HexToColor3(getgenv().Config.ESP.NameColor)
        self.Drawings.Distance.Visible = true
    else
        self.Drawings.Distance.Visible = false
    end
    
    -- Health Bar
    if getgenv().Config.ESP.ShowHealth then
        local healthPercent = humanoid.Health / humanoid.MaxHealth
        local barWidth = 4
        local barHeight = max.Y - min.Y
        
        self.Drawings.HealthBarOutline.Size = Vector2.new(barWidth, barHeight)
        self.Drawings.HealthBarOutline.Position = Vector2.new(min.X - barWidth - 2, min.Y)
        self.Drawings.HealthBarOutline.Visible = true
        
        local healthBarHeight = barHeight * healthPercent
        self.Drawings.HealthBar.Size = Vector2.new(barWidth - 2, healthBarHeight)
        self.Drawings.HealthBar.Position = Vector2.new(min.X - barWidth - 1, min.Y + (barHeight - healthBarHeight))
        self.Drawings.HealthBar.Visible = true
        
        if healthPercent > 0.6 then
            self.Drawings.HealthBar.Color = Color3.fromRGB(0, 255, 0)
        elseif healthPercent > 0.3 then
            self.Drawings.HealthBar.Color = Color3.fromRGB(255, 255, 0)
        else
            self.Drawings.HealthBar.Color = Color3.fromRGB(255, 0, 0)
        end
    else
        self.Drawings.HealthBar.Visible = false
        self.Drawings.HealthBarOutline.Visible = false
    end
    
    -- Tracer
    if getgenv().Config.ESP.ShowTracers then
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        local targetPos = Vector2.new((min.X + max.X) / 2, max.Y)
        
        self.Drawings.Tracer.From = screenCenter
        self.Drawings.Tracer.To = targetPos
        self.Drawings.Tracer.Color = HexToColor3(getgenv().Config.ESP.TracerColor)
        self.Drawings.Tracer.Visible = true
    else
        self.Drawings.Tracer.Visible = false
    end
end

-- ESP Manager Functions
function ESPModule.createESP(player)
    if player == LOCAL_PLAYER then return end
    if ESPModule.ESPObjects[player] then
        ESPModule.ESPObjects[player]:Remove()
    end
    ESPModule.ESPObjects[player] = ESPObject.new(player)
end

function ESPModule.removeESP(player)
    if ESPModule.ESPObjects[player] then
        ESPModule.ESPObjects[player]:Remove()
        ESPModule.ESPObjects[player] = nil
    end
end

function ESPModule.updateAll()
    for player, esp in pairs(ESPModule.ESPObjects) do
        if player.Parent and Players:FindFirstChild(player.Name) then
            esp:Update()
        else
            ESPModule.removeESP(player)
        end
    end
end

function ESPModule.init()
    -- Initialize ESP for existing players
    for _, player in pairs(Players:GetPlayers()) do
        ESPModule.createESP(player)
    end

    -- Connect player added/removed
    Players.PlayerAdded:Connect(ESPModule.createESP)
    Players.PlayerRemoving:Connect(ESPModule.removeESP)

    -- Connect update loop
    RunService.Heartbeat:Connect(ESPModule.updateAll)
end

function ESPModule.updateESPColors(color)
    local hexColor = Color3ToHex(color)
    getgenv().Config.ESP.BoxColor = hexColor
    getgenv().Config.ESP.NameColor = hexColor
    getgenv().Config.ESP.TracerColor = hexColor
    
    for player, esp in pairs(ESPModule.ESPObjects) do
        if esp and esp.Drawings then
            if esp.Drawings.Box then esp.Drawings.Box.Color = color end
            if esp.Drawings.Name then esp.Drawings.Name.Color = color end
            if esp.Drawings.Distance then esp.Drawings.Distance.Color = color end
            if esp.Drawings.Tracer then esp.Drawings.Tracer.Color = color end
        end
    end
end

return ESPModule
