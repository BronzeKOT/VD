-- opener
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "KOT HUB"
gui.Parent = game:GetService("CoreGui")

local frame = Instance.new("Frame")
frame.Name = "OpenMenu"
frame.Size = UDim2.new(0, 400, 0, 60)
frame.Position = UDim2.new(0.5, -200, 0.5, -175)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Name"
title.Size = UDim2.new(1, -340, 0, 50)
title.Position = UDim2.new(0, 55, 0, 5)
title.BackgroundTransparency = 1
title.Text = "KOT HUB"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 15
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local image = Instance.new("ImageLabel")
image.Name = "Preview"
image.Size = UDim2.new(0, 50, 0, 50)
image.Position = UDim2.new(0, 5, 0, 5)
image.BackgroundTransparency = 1
image.Image = "rbxassetid://284402752"
image.ScaleType = Enum.ScaleType.Fit
image.Parent = frame

local btn1 = Instance.new("TextButton")
btn1.Name = "Open"
btn1.Size = UDim2.new(0, 40, 0, 40)
btn1.Rotation = 90
btn1.Position = UDim2.new(0, 350, 0, 5)
btn1.BackgroundColor3 = Color3.fromRGB(85, 0, 0)
btn1.Text = ">"
btn1.TextColor3 = Color3.fromRGB(255, 255, 255)
btn1.TextSize = 16
btn1.Font = Enum.Font.GothamBold
btn1.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = btn1

-- ============================================================================== Root menu
local root = Instance.new("ScreenGui")
root.Name = "Root"
root.Enabled = false
root.Parent = game:GetService("CoreGui")

local menu = Instance.new("Frame")
menu.Name = "Menu"
menu.Size = UDim2.new(0, 600, 0, 700)
menu.Position = UDim2.new(0.5, -300, 0.5, -350)
menu.BackgroundColor3 = Color3.fromRGB(66, 0, 0)
menu.BorderColor3 = Color3.fromRGB(8, 0, 53)
menu.BorderMode = Enum.BorderMode.Inset
menu.BorderSizePixel = 5
menu.Active = true
menu.Draggable = true
menu.Parent = root

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 10)
menuCorner.Parent = menu

local Gradient = Instance.new("Frame")
Gradient.Name = "Gradient"
Gradient.Size = UDim2.new(1, 0, 1, 0)
Gradient.Position = UDim2.new(0, 0, 0, 0)
Gradient.BackgroundColor3 = Color3.fromRGB(41, 0, 0)
Gradient.BorderSizePixel = 0
Gradient.Active = false
Gradient.Draggable = false
Gradient.ZIndex = 1
Gradient.Parent = menu

local gradientCorner = Instance.new("UICorner")
gradientCorner.CornerRadius = UDim.new(0, 10)
gradientCorner.Parent = Gradient

local menuGrad = Instance.new("UIGradient")
menuGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(1, 0.95)
})
menuGrad.Rotation = 90
menuGrad.Parent = Gradient

-- ============================================================== PLAYER Dash
local DashConfig = {
    normalDuration = 1.0,
    dashDuration   = 0.5,
    dashSpeed      = 25,
}

local DashState = {
    enabled      = false,
    thread       = nil,
    humanoid     = nil,
    rootPart     = nil,
    originalWalkSpeed = nil,
    dashVelocity = nil,
}

local function dashLog(...) print("[DashCycle]", ...) end

local function dashCleanupVelocity()
    if DashState.dashVelocity then
        pcall(function() DashState.dashVelocity:Destroy() end)
        DashState.dashVelocity = nil
    end
    if DashState.rootPart then
        local old = DashState.rootPart:FindFirstChild("DashVel")
        if old then pcall(function() old:Destroy() end) end
        local att = DashState.rootPart:FindFirstChild("DashAtt")
        if att then pcall(function() att:Destroy() end) end
    end
end

local function dashDoDash()
    if not DashState.rootPart or not DashState.humanoid then return end

    local dir = DashState.humanoid.MoveDirection
    if dir.Magnitude < 0.1 then
        local cam = workspace.CurrentCamera
        dir = cam and Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z) or Vector3.new(0,0,-1)
    end
    if dir.Magnitude > 0.01 then dir = dir.Unit end

    local att = Instance.new("Attachment")
    att.Name = "DashAtt"
    att.Parent = DashState.rootPart

    local lv = Instance.new("LinearVelocity")
    lv.Name = "DashVel"
    lv.Attachment0 = att
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    lv.MaxAxesForce = Vector3.new(1e999, 0, 1e999)
    lv.VectorVelocity = dir * DashConfig.dashSpeed
    lv.Parent = DashState.rootPart

    DashState.dashVelocity = lv
    dashLog(string.format("DASH %.2fs | speed=%.0f", DashConfig.dashDuration, DashConfig.dashSpeed))

    task.delay(DashConfig.dashDuration, function()
        if DashState.dashVelocity == lv then
            pcall(function() lv:Destroy() end)
            if att then pcall(function() att:Destroy() end) end
            DashState.dashVelocity = nil
        end
    end)
end

local function dashCycleLoop()
    while DashState.enabled do
        if DashState.originalWalkSpeed and DashState.humanoid then
            DashState.humanoid.WalkSpeed = DashState.originalWalkSpeed
        end
        dashCleanupVelocity()
        task.wait(DashConfig.normalDuration)
        if not DashState.enabled then break end

        dashDoDash()
        task.wait(DashConfig.dashDuration)
    end
end

local function dashStart()
    if DashState.enabled then return end
    if not DashState.humanoid then dashLog("Нет Humanoid"); return end
    DashState.enabled = true
    DashState.originalWalkSpeed = DashState.humanoid.WalkSpeed
    DashState.thread = task.spawn(dashCycleLoop)
    dashLog("Cycle ON")
end

local function dashStop()
    if not DashState.enabled then return end
    DashState.enabled = false
    if DashState.thread then pcall(task.cancel, DashState.thread) end
    DashState.thread = nil
    dashCleanupVelocity()
    if DashState.humanoid and DashState.originalWalkSpeed then
        DashState.humanoid.WalkSpeed = DashState.originalWalkSpeed
    end
    dashLog("Cycle OFF")
end

local function dashToggle()
    if DashState.enabled then dashStop() else dashStart() end
    return DashState.enabled
end

-- Бинд персонажа
local function dashBindCharacter(char)
    DashState.humanoid = char:WaitForChild("Humanoid", 10)
    DashState.rootPart = char:WaitForChild("HumanoidRootPart", 10)
    dashCleanupVelocity()
    DashState.originalWalkSpeed = DashState.humanoid and DashState.humanoid.WalkSpeed
end

if LocalPlayer.Character then dashBindCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(dashBindCharacter)

-- ========================================================================================================= GROUND RING ENGINE
local RingEngine = {
    rings = {},
    heartbeatConn = nil,
    renderConn = nil,
    config = {
        radius        = 6,
        segmentCount  = 24,
        dashLength    = 0.55,
        segmentWidth  = 0.25,
        segmentHeight = 0.08,
        groundOffset  = -2.95,
    },
}

local function ringLog(...) print("[RingEngine]", ...) end

local function getPlayerRoleSafe(p)
    if p.Team then
        local tn = p.Team.Name:lower()
        if tn:find("killer")   then return "Killer"   end
        if tn:find("survivor") then return "Survivor" end
    end
    local char = p.Character
    if char then
        local CollectionService = game:GetService("CollectionService")
        if CollectionService:HasTag(char, "Killer")   then return "Killer"   end
        if CollectionService:HasTag(char, "Survivor") then return "Survivor" end
        if char:GetAttribute("MorphedKiller") or char:GetAttribute("Abysswalker") then
            return "Killer"
        end
    end
    return nil
end

local function createRingFor(p, color)
    local char = p.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local existing = RingEngine.rings[p]
    if existing then
        for _, seg in ipairs(existing.segments) do
            pcall(function() seg.part:Destroy() end)
        end
        RingEngine.rings[p] = nil
    end

    local cfg = RingEngine.config
    local segments = {}
    local step    = (math.pi * 2) / cfg.segmentCount
    local arcLen  = (math.pi * 2 * cfg.radius) / cfg.segmentCount
    local dashLen = arcLen * cfg.dashLength

    for i = 1, cfg.segmentCount do
        local angle = (i - 1) * step
        local seg = Instance.new("Part")
        seg.Name = "RingSeg"
        seg.Size = Vector3.new(cfg.segmentWidth, cfg.segmentHeight, dashLen)
        seg.Anchored = true
        seg.CanCollide = false
        seg.CanQuery = false
        seg.CanTouch = false
        seg.CastShadow = false
        seg.Material = Enum.Material.Neon
        seg.Color = color
        seg.Transparency = 0
        seg.Parent = workspace

        local hl = Instance.new("Highlight")
        hl.Adornee = seg
        hl.FillColor = color
        hl.FillTransparency = 1
        hl.OutlineColor = color
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = seg

        table.insert(segments, { part = seg, angle = angle })
    end

    RingEngine.rings[p] = { segments = segments, color = color, hrp = hrp }
    return RingEngine.rings[p]
end

local function removeRingFor(p)
    local data = RingEngine.rings[p]
    if not data then return end
    for _, seg in ipairs(data.segments) do
        pcall(function() seg.part:Destroy() end)
    end
    RingEngine.rings[p] = nil
end

-- Обновление кольца одного игрока. Использует позицию HRP из текущего кадра.
local function updateRingFor(p, data)
    local cfg = RingEngine.config
    local char = p.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        removeRingFor(p)
        return
    end
    data.hrp = hrp

    -- ВАЖНО: для LocalPlayer берём позицию из рендер-кадра (CFrame), для чужих — Position
    local pos
    if p == LocalPlayer then
        pos = hrp.CFrame.Position
    else
        pos = hrp.Position
    end
    local floorY = pos.Y + cfg.groundOffset

    for _, segData in ipairs(data.segments) do
        local seg = segData.part
        if seg and seg.Parent then
            local x = math.cos(segData.angle) * cfg.radius
            local z = math.sin(segData.angle) * cfg.radius
            seg.CFrame = CFrame.new(pos.X + x, floorY, pos.Z + z)
                * CFrame.Angles(0, -segData.angle, 0)
        end
    end
end

-- Чужие кольца — Heartbeat
local function updateRemoteRings()
    for p, data in pairs(RingEngine.rings) do
        if p ~= LocalPlayer then
            updateRingFor(p, data)
        end
    end
end

-- Своё кольцо — RenderStepped (чтобы не отставало)
local function updateSelfRing()
    local data = RingEngine.rings[LocalPlayer]
    if data then
        updateRingFor(LocalPlayer, data)
    end
end

local function startRingEngine()
    if RingEngine.heartbeatConn then return end
    RingEngine.heartbeatConn = RunService.Heartbeat:Connect(updateRemoteRings)
    RingEngine.renderConn   = RunService.RenderStepped:Connect(updateSelfRing)
end

local function stopRingEngine()
    if RingEngine.heartbeatConn then
        pcall(function() RingEngine.heartbeatConn:Disconnect() end)
        RingEngine.heartbeatConn = nil
    end
    if RingEngine.renderConn then
        pcall(function() RingEngine.renderConn:Disconnect() end)
        RingEngine.renderConn = nil
    end
    for p, _ in pairs(RingEngine.rings) do
        removeRingFor(p)
    end
end

-- ============================================================== PLAYER ESP
local playerESPOn = false
local playerESPData = {}
local playerESPHeartbeat = nil
local ignoreList = {}

local function alive(i) return i ~= nil and i.Parent ~= nil end
local function getMyPos()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    return h and h.Position
end

local function makeHighlight(adornee, fill, outline, parent)
    local hl = Instance.new("Highlight")
    hl.Adornee             = adornee
    hl.FillColor           = fill
    hl.OutlineColor        = outline or Color3.new(1,1,1)
    hl.FillTransparency    = 0.45
    hl.OutlineTransparency = 0
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent              = parent or adornee
    return hl
end

local function makeBillboard(text, color, studOff, sizeX, sizeY)
    local bg = Instance.new("BillboardGui")
    bg.Name        = "KOT_ESP"
    bg.AlwaysOnTop = true
    bg.Size        = UDim2.new(0, sizeX or 160, 0, sizeY or 40)
    bg.StudsOffset = Vector3.new(0, studOff or 3, 0)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size                   = UDim2.new(1,0,1,0)
    lbl.Font                   = Enum.Font.GothamBold
    lbl.Text                   = text or ""
    lbl.TextSize               = 14
    lbl.TextColor3             = color or Color3.new(1,1,1)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3       = Color3.new(0,0,0)
    lbl.Parent                 = bg
    return bg, lbl
end

local function getPlayerRole(p)
    if not p.Team then return "Player" end
    local tn = p.Team.Name:lower()
    if tn:find("killer")   then return "Killer"   end
    if tn:find("survivor") then return "Survivor" end
    return p.Team.Name
end

local function roleColor(role)
    if role == "Killer"   then return Color3.fromRGB(255,70,70)  end
    if role == "Survivor" then return Color3.fromRGB(80,200,255) end
    return Color3.fromRGB(200,200,200)
end

local function roleFill(role)
    if role == "Killer"   then return Color3.fromRGB(220,30,30)  end
    if role == "Survivor" then return Color3.fromRGB(30,120,220) end
    return Color3.fromRGB(120,120,120)
end

local function removePlayerESP(p)
    local d = playerESPData[p]
    if not d then return end
    pcall(function() if d.hl and alive(d.hl) then d.hl:Destroy() end end)
    pcall(function() if d.bb and alive(d.bb) then d.bb:Destroy() end end)
    playerESPData[p] = nil
end

local function addPlayerESP(p)
    if not playerESPOn then return end
    if p == LocalPlayer or ignoreList[p.Name] then return end
    local char = p.Character
    if not (char and char:FindFirstChild("HumanoidRootPart")) then return end

    removePlayerESP(p)

    local role = getPlayerRole(p)
    local col  = roleColor(role)
    local fill = roleFill(role)

    local hl = makeHighlight(char, fill, Color3.new(1,1,1), char)
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    local bb, lbl = makeBillboard(role, col, 2.8, 180, 46)
    lbl.TextSize  = 16
    bb.AlwaysOnTop = true
    bb.Parent = head

    playerESPData[p] = { hl=hl, bb=bb, lbl=lbl, role=role }
end

local function rebuildPlayerESP()
    for p, _ in pairs(playerESPData) do removePlayerESP(p) end
    playerESPData = {}
    if not playerESPOn then return end
    for _, p in ipairs(Players:GetPlayers()) do addPlayerESP(p) end
end

local function startPlayerESPHeartbeat()
    if playerESPHeartbeat then return end
    playerESPHeartbeat = RunService.Heartbeat:Connect(function()
        if not playerESPOn then return end
        local myPos = getMyPos()
        for p, d in pairs(playerESPData) do
            if not (alive(d.bb) and p.Character and alive(p.Character)) then
                removePlayerESP(p)
                continue
            end
            local role = getPlayerRole(p)
            if role ~= d.role then
                d.role = role
                if d.lbl then
                    d.lbl.Text = role
                    d.lbl.TextColor3 = roleColor(role)
                end
                if d.hl then
                    d.hl.FillColor = roleFill(role)
                end
            end
            if d.lbl and myPos then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dist = (hrp.Position - myPos).Magnitude
                    d.lbl.Text = string.format("%s  %.0f", role, dist)
                end
            end
        end
    end)
end

local function stopPlayerESPHeartbeat()
    if playerESPHeartbeat then playerESPHeartbeat:Disconnect(); playerESPHeartbeat = nil end
end

local function watchTeam(p)
    p:GetPropertyChangedSignal("Team"):Connect(function()
        if not playerESPOn then return end
        removePlayerESP(p)
        addPlayerESP(p)
    end)
end

Players.PlayerAdded:Connect(function(p)
    watchTeam(p)
    p.CharacterAdded:Connect(function()
        if playerESPOn then task.wait(0.5); addPlayerESP(p) end
    end)
end)
for _, p in ipairs(Players:GetPlayers()) do watchTeam(p) end
Players.PlayerRemoving:Connect(function(p) removePlayerESP(p) end)
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if playerESPOn then rebuildPlayerESP() end
end)

-- ============================================================== AUTO SKILLCHECK
local GEN_SKILL_ENABLED = false
local HEAL_SKILL_ENABLED = false
local SKILL_SUCCESS_PROB = 1
local SKILL_DELAY = 0.6

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Generator = Remotes:WaitForChild("Generator")
local GenSkillCheckEvent = Generator:WaitForChild("SkillCheckEvent")
local GenSkillCheckResultEvent = Generator:WaitForChild("SkillCheckResultEvent")

local Healing = Remotes:WaitForChild("Healing")
local HealSkillCheckEvent = Healing:WaitForChild("SkillCheckEvent")
local HealSkillCheckResultEvent = Healing:WaitForChild("SkillCheckResultEvent")

local function releaseMouse()
    pcall(function()
        local mouse = LocalPlayer:GetMouse()
        if mousemoverel then
            mousemoverel(-mouse.X + 10, -mouse.Y + 10)
        end
    end)
    pcall(function() if mouse1release then mouse1release() end end)
    pcall(function()
        local VU = game:GetService("VirtualUser")
        local mouse = LocalPlayer:GetMouse()
        VU:Button1Up(Vector2.new(mouse.X, mouse.Y))
    end)
end

GenSkillCheckEvent.OnClientEvent:Connect(function(gen, part, requestId, parent, repairRequestId)
    if not GEN_SKILL_ENABLED then return end
    if parent ~= LocalPlayer.Character then return end
    task.wait(SKILL_DELAY)
    local checkInterractable = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("CheckInterractable")
    if not checkInterractable or not checkInterractable:GetAttribute("isRepairing") then return end
    local result = (math.random() <= SKILL_SUCCESS_PROB) and "success" or "neutral"
    pcall(function()
        GenSkillCheckResultEvent:FireServer(result, 1, gen, part, requestId, parent)
    end)
    releaseMouse()
end)

HealSkillCheckEvent.OnClientEvent:Connect(function(targetPlayer, requestId, parent, healRequestId)
    if not HEAL_SKILL_ENABLED then return end
    if parent ~= LocalPlayer.Character then return end
    task.wait(SKILL_DELAY)
    local checkInterractable = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("CheckInterractable")
    if not checkInterractable or not checkInterractable:GetAttribute("isHealing") then return end
    local result = (math.random() <= SKILL_SUCCESS_PROB) and "success" or "neutral"
    pcall(function()
        HealSkillCheckResultEvent:FireServer(result, 1, targetPlayer, requestId, parent)
    end)
    releaseMouse()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.E then
        releaseMouse()
    end
end)

-- ============================================================== CURSOR
local CursorSettings = {
    enabled = false,
    spinSpeed = 90,
    offset = 8,
    tickLength = 10,
    tickThickness = 2,
    color = Color3.fromRGB(255, 255, 255),
}

local CursorGui = Instance.new("ScreenGui")
CursorGui.Name = "CustomCursor"
CursorGui.ResetOnSpawn = false
CursorGui.IgnoreGuiInset = true
CursorGui.DisplayOrder = 999999
CursorGui.Enabled = false
CursorGui.Parent = game:GetService("CoreGui")

local cursorContainer = Instance.new("Frame")
cursorContainer.Name = "Container"
cursorContainer.Size = UDim2.new(0, 0, 0, 0)
cursorContainer.BackgroundTransparency = 1
cursorContainer.ZIndex = 999
cursorContainer.Parent = CursorGui

local function makeTick(name)
    local f = Instance.new("Frame")
    f.Name = name
    f.Size = UDim2.new(0, CursorSettings.tickThickness, 0, CursorSettings.tickLength)
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.BackgroundColor3 = CursorSettings.color
    f.BorderSizePixel = 0
    f.ZIndex = 999
    f.Parent = cursorContainer
    return f
end

local tick1 = makeTick("1")
local tick2 = makeTick("2")
local tick3 = makeTick("3")

local cursorAngle = 0

RunService.RenderStepped:Connect(function(dt)
    if not CursorSettings.enabled then return end
    local mouse = UserInputService:GetMouseLocation()
    cursorContainer.Position = UDim2.new(0, mouse.X, 0, mouse.Y)
    cursorAngle = (cursorAngle + CursorSettings.spinSpeed * dt) % 360

    local function place(tick, baseAngle)
        local rad = math.rad(baseAngle + cursorAngle)
        local dx = math.sin(rad) * CursorSettings.offset
        local dy = -math.cos(rad) * CursorSettings.offset
        tick.Position = UDim2.new(0.5, dx, 0.5, dy)
        tick.Rotation = baseAngle + cursorAngle
        tick.Size = UDim2.new(0, CursorSettings.tickThickness, 0, CursorSettings.tickLength)
        tick.BackgroundColor3 = CursorSettings.color
    end

    place(tick1, 0)
    place(tick2, 120)
    place(tick3, -120)
end)

-- ============================================================== ФУНКЦИИ ДЛЯ КАРТОЧЕК
local function makeCard(parent, name, desc)
    local card = Instance.new("Frame")
    card.Name = name
    card.Size = UDim2.new(1, 0, 0, 70)
    card.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
    card.BorderSizePixel = 0
    card.ZIndex = 2
    card.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = card

    local g = Instance.new("UIGradient")
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0.95)
    })
    g.Rotation = 180
    g.Parent = card

    local lbl = Instance.new("TextLabel")
    lbl.Name = "NameFunct"
    lbl.Size = UDim2.new(1, -100, 0, 25)
    lbl.Position = UDim2.new(0, 10, 0, 8)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextSize = 15
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 3
    lbl.Parent = card

    local d = Instance.new("TextLabel")
    d.Name = "Desc"
    d.Size = UDim2.new(1, -100, 0, 25)
    d.Position = UDim2.new(0, 10, 0, 35)
    d.BackgroundTransparency = 1
    d.Text = desc or ""
    d.TextColor3 = Color3.fromRGB(180, 180, 180)
    d.TextSize = 12
    d.Font = Enum.Font.Gotham
    d.TextXAlignment = Enum.TextXAlignment.Left
    d.ZIndex = 3
    d.Parent = card

    local btn = Instance.new("TextButton")
    btn.Name = "On/Off"
    btn.Size = UDim2.new(0, 70, 0, 30)
    btn.Position = UDim2.new(1, -80, 0, 20)
    btn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
    btn.Text = "OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.ZIndex = 3
    btn.Parent = card

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 6)
    bc.Parent = btn

    return btn, lbl, d, card
end

-- Хелпер: карточка с числовым полем ввода
local function makeNumberCard(parent, title, desc, initialValue, minVal, maxVal, step, onChange)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 70)
    card.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
    card.BorderSizePixel = 0
    card.ZIndex = 2
    card.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = card

    local g = Instance.new("UIGradient")
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0.95)
    })
    g.Rotation = 180
    g.Parent = card

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -120, 0, 25)
    lbl.Position = UDim2.new(0, 10, 0, 8)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextSize = 15
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 3
    lbl.Parent = card

    local d = Instance.new("TextLabel")
    d.Size = UDim2.new(1, -120, 0, 25)
    d.Position = UDim2.new(0, 10, 0, 35)
    d.BackgroundTransparency = 1
    d.Text = desc or ""
    d.TextColor3 = Color3.fromRGB(180, 180, 180)
    d.TextSize = 11
    d.Font = Enum.Font.Gotham
    d.TextXAlignment = Enum.TextXAlignment.Left
    d.ZIndex = 3
    d.Parent = card

    -- Поле ввода
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 90, 0, 30)
    box.Position = UDim2.new(1, -100, 0, 20)
    box.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    box.Text = tostring(initialValue)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.TextSize = 14
    box.Font = Enum.Font.GothamBold
    box.ClearTextOnFocus = false
    box.ZIndex = 3
    box.Parent = card

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 4)
    bc.Parent = box

    local function apply(text)
        local num = tonumber(text)
        if not num then
            box.Text = tostring(initialValue)
            return
        end
        num = math.clamp(num, minVal, maxVal)
        -- округление до шага
        num = math.floor(num / step + 0.5) * step
        num = math.clamp(num, minVal, maxVal)
        box.Text = tostring(num)
        initialValue = num
        onChange(num)
    end

    box.FocusLost:Connect(function() apply(box.Text) end)
    box:GetPropertyChangedSignal("Text"):Connect(function()
        -- валидация на лету
        local num = tonumber(box.Text)
        if num then
            num = math.clamp(num, minVal, maxVal)
            onChange(num)
        end
    end)

    return card, box
end

-- ============================================================== ВКЛАДКИ (панели)
local function makePanel(name)
    local f = Instance.new("Frame")
    f.Name = name
    f.Size = UDim2.new(0, 390, 1, 0)
    f.Position = UDim2.new(0, 200, 0, 0)
    f.BackgroundColor3 = Color3.fromRGB(41, 0, 0)
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.Visible = false
    f.Active = false
    f.Draggable = false
    f.ZIndex = 2
    f.Parent = menu

    local sc = Instance.new("ScrollingFrame")
    sc.Name = "scrl bar"
    sc.Size = UDim2.new(1, 0, 1, 0)
    sc.Position = UDim2.new(0, 0, 0, 0)
    sc.BackgroundColor3 = Color3.fromRGB(41, 0, 0)
    sc.BackgroundTransparency = 1
    sc.BorderSizePixel = 0
    sc.Active = true
    sc.ScrollBarThickness = 6
    sc.ScrollBarImageColor3 = Color3.fromRGB(85, 0, 0)
    sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.ScrollingDirection = Enum.ScrollingDirection.Y
    sc.ZIndex = 2
    sc.Parent = f

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 10)
    c.Parent = sc

    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 15)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = sc

    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, 20)
    p.PaddingLeft = UDim.new(0, 20)
    p.PaddingRight = UDim.new(0, 20)
    p.PaddingBottom = UDim.new(0, 20)
    p.Parent = sc

    return f, sc
end

local Killer, scrlK = makePanel("Killer P")
local Survival, scrlS = makePanel("Survival P")
local Esp, scrlE = makePanel("ESP P")
local PlayerFrame, scrlP = makePanel("Player P")
local Troll, scrlT = makePanel("Troll P")
local World, scrlW = makePanel("World P")
local Server, scrlSr = makePanel("Server P")
local Settings, scrlSt = makePanel("Settings P")
local Credits, scrlC = makePanel("Credits P")

-- ============================================================== ЗАГОТОВКИ
makeCard(scrlK, "Killer Function 1", "Placeholder")
makeCard(scrlK, "Killer Function 2", "Placeholder")

makeCard(scrlSr, "Server Function 1", "Placeholder")

makeCard(scrlSt, "Settings Function 1", "Placeholder")

makeCard(scrlC, "Credits", "KOT HUB")

-- ============================================================== WORLD: Bright (FB)
local BrightEnabled = false
local BrightBackup = nil

local function setBright(on)
    local Lighting = game:GetService("Lighting")
    
    if on then
        if not BrightBackup then
            BrightBackup = {
                Brightness = Lighting.Brightness,
                ExposureCompensation = Lighting.ExposureCompensation,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
            }
        end
        Lighting.Brightness = 6
        Lighting.ExposureCompensation = 2
        Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
        BrightEnabled = true
    else
        if BrightBackup then
            Lighting.Brightness = BrightBackup.Brightness
            Lighting.ExposureCompensation = BrightBackup.ExposureCompensation
            Lighting.Ambient = BrightBackup.Ambient
            Lighting.OutdoorAmbient = BrightBackup.OutdoorAmbient
            BrightBackup = nil
        end
        BrightEnabled = false
    end
end

local brightBtn = makeCard(scrlW, "FB (Bright)", "Яркое освещение — вкл/выкл")
brightBtn.MouseButton1Click:Connect(function()
    setBright(not BrightEnabled)
    brightBtn.Text = BrightEnabled and "ON" or "OFF"
    brightBtn.BackgroundColor3 = BrightEnabled and Color3.fromRGB(30,150,30) or Color3.fromRGB(180,30,30)
end)

-- ============================================================== WORLD: NoFog
local NoFogEnabled = false
local NoFogBackup = nil

local function setNoFog(on)
    local Lighting = game:GetService("Lighting")
    
    if on then
        if not NoFogBackup then
            NoFogBackup = {
                FogStart = Lighting.FogStart,
                FogEnd = Lighting.FogEnd,
                FogColor = Lighting.FogColor,
            }
            -- Сохраняем плотность атмосфер (если есть)
            NoFogBackup.Atmospheres = {}
            for _, v in ipairs(Lighting:GetChildren()) do
                if v:IsA("Atmosphere") then
                    NoFogBackup.Atmospheres[v] = v.Density
                end
            end
        end
        -- Убираем туман
        Lighting.FogStart = 100000
        Lighting.FogEnd = 100000
        -- Атмосферы в 0
        for atm, _ in pairs(NoFogBackup.Atmospheres) do
            if atm and atm.Parent then
                atm.Density = 0
            end
        end
        NoFogEnabled = true
    else
        if NoFogBackup then
            Lighting.FogStart = NoFogBackup.FogStart
            Lighting.FogEnd = NoFogBackup.FogEnd
            Lighting.FogColor = NoFogBackup.FogColor
            for atm, dens in pairs(NoFogBackup.Atmospheres) do
                if atm and atm.Parent then
                    atm.Density = dens
                end
            end
            NoFogBackup = nil
        end
        NoFogEnabled = false
    end
end

local nofogBtn = makeCard(scrlW, "NoFog", "Убирает туман — вкл/выкл")
nofogBtn.MouseButton1Click:Connect(function()
    setNoFog(not NoFogEnabled)
    nofogBtn.Text = NoFogEnabled and "ON" or "OFF"
    nofogBtn.BackgroundColor3 = NoFogEnabled and Color3.fromRGB(30,150,30) or Color3.fromRGB(180,30,30)
end)

-- ============================================================== TROLL: Jerk Off
local JerkState = {
    enabled = false,
    tool = nil,
    anims = {},
    conns = {},
    playing = false,
}

local function jerkStopAnims()
    JerkState.playing = false
    for id, conn in pairs(JerkState.conns) do
        pcall(function() conn:Disconnect() end)
        JerkState.conns[id] = nil
    end
    for _, anim in pairs(JerkState.anims) do
        pcall(function() anim:Stop() end)
    end
    JerkState.anims = {}
end

local function jerkPlayAnim(id, t1, t2, key)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local a = Instance.new("Animation")
    a.AnimationId = "rbxassetid://" .. id
    local tr = hum:LoadAnimation(a)
    JerkState.anims[key] = tr

    JerkState.conns[key] = RunService.RenderStepped:Connect(function()
        if JerkState.playing then
            if tr.TimePosition >= t2 or tr.IsPlaying == false then
                tr:Play()
                tr.TimePosition = t1
            end
        else
            tr:Stop()
        end
    end)

    tr:Play()
    tr.TimePosition = t1
end

local function jerkStart()
    JerkState.playing = true
    jerkPlayAnim("72042024", 0.5, 0.9, 1)
    jerkPlayAnim("168268306", 1, 1.001, 2)
end

local function jerkCreateTool()
    if JerkState.tool and JerkState.tool.Parent then return end
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not backpack then return end

    local tool = Instance.new("Tool")
    tool.Name = "Jerk Off"
    tool.RequiresHandle = false
    tool.Parent = backpack

    tool.Equipped:Connect(function()
        if JerkState.enabled then
            jerkStart()
        end
    end)
    tool.Unequipped:Connect(function()
        jerkStopAnims()
    end)

    JerkState.tool = tool
end

local function jerkRemoveTool()
    jerkStopAnims()
    if JerkState.tool then
        pcall(function() JerkState.tool:Destroy() end)
        JerkState.tool = nil
    end
    -- на случай если остался в Character
    local char = LocalPlayer.Character
    if char then
        local t = char:FindFirstChild("Jerk Off")
        if t then pcall(function() t:Destroy() end) end
    end
end

local function jerkSetEnabled(on)
    JerkState.enabled = on
    if on then
        jerkCreateTool()
    else
        jerkRemoveTool()
    end
end

-- Пересоздание тула при респавне, если включено
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if JerkState.enabled then
        jerkCreateTool()
    end
end)

-- Карточка в Troll
local jerkBtn = makeCard(scrlT, "Jerk Off", "Tool + анимация. OFF = предмет удалён")
jerkBtn.MouseButton1Click:Connect(function()
    JerkState.enabled = not JerkState.enabled
    jerkBtn.Text = JerkState.enabled and "ON" or "OFF"
    jerkBtn.BackgroundColor3 = JerkState.enabled and Color3.fromRGB(30,150,30) or Color3.fromRGB(180,30,30)
    jerkSetEnabled(JerkState.enabled)
end)
-- ============================================================== ESP (с логикой)
local espBtn = makeCard(scrlE, "Player ESP", "Highlight players, show role + distance")
espBtn.MouseButton1Click:Connect(function()
    playerESPOn = not playerESPOn
    espBtn.Text = playerESPOn and "ON" or "OFF"
    espBtn.BackgroundColor3 = playerESPOn and Color3.fromRGB(30,150,30) or Color3.fromRGB(180,30,30)
    if playerESPOn then
        rebuildPlayerESP()
        startPlayerESPHeartbeat()
    else
        rebuildPlayerESP()
        stopPlayerESPHeartbeat()
    end
end)

-- ============================================================== ESP CURSOR
local cursorBtn = makeCard(scrlE, "Custom Crosshair", "Spin cursor, configurable")
cursorBtn.MouseButton1Click:Connect(function()
    CursorSettings.enabled = not CursorSettings.enabled
    cursorBtn.Text = CursorSettings.enabled and "ON" or "OFF"
    cursorBtn.BackgroundColor3 = CursorSettings.enabled and Color3.fromRGB(30,150,30) or Color3.fromRGB(180,30,30)
    CursorGui.Enabled = CursorSettings.enabled
end)

-- ============================================================== GENERATOR PROGRESS UI (modules)
local GeneratorUI = (function()
    local RED_COLOR    = Color3.fromRGB(200, 30, 30)
    local GREEN_COLOR  = Color3.fromRGB(50, 200, 70)
    local GRAY_COLOR   = Color3.fromRGB(55, 55, 55)
    local SIZE         = 50
    local MAX_DIST     = 500
    local HEIGHT_OFF   = 4

    local enabled = false

    local camera = workspace.CurrentCamera

    -- // Удаляем старый, если остался
    local CoreGui = game:GetService("CoreGui")
    local old = CoreGui:FindFirstChild("GeneratorUI")
    if old then old:Destroy() end
    local oldP = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if oldP then
        local o = oldP:FindFirstChild("GeneratorUI")
        if o then o:Destroy() end
    end

    local screen = Instance.new("ScreenGui")
    screen.Name = "GeneratorUI"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.DisplayOrder = 999
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    -- На CoreGui (как остальной хаб)
    local ok = pcall(function() screen.Parent = CoreGui end)
    if not ok then
        screen.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    end

    local function createCircle()
        local outer = Instance.new("Frame")
        outer.Size = UDim2.fromOffset(SIZE + 6, SIZE + 6)
        outer.AnchorPoint = Vector2.new(0.5, 0.5)
        outer.BackgroundColor3 = RED_COLOR
        outer.BackgroundTransparency = 0
        outer.BorderSizePixel = 0
        outer.Visible = false
        outer.Parent = screen

        local oc = Instance.new("UICorner")
        oc.CornerRadius = UDim.new(1, 0)
        oc.Parent = outer

        local outerStroke = Instance.new("UIStroke")
        outerStroke.Color = RED_COLOR
        outerStroke.Thickness = 1
        outerStroke.Transparency = 0.3
        outerStroke.Parent = outer

        local inner = Instance.new("Frame")
        inner.Size = UDim2.fromOffset(SIZE, SIZE)
        inner.AnchorPoint = Vector2.new(0.5, 0.5)
        inner.Position = UDim2.fromScale(0.5, 0.5)
        inner.BackgroundColor3 = GRAY_COLOR
        inner.BackgroundTransparency = 0.05
        inner.BorderSizePixel = 0
        inner.Parent = outer

        local ic = Instance.new("UICorner")
        ic.CornerRadius = UDim.new(1, 0)
        ic.Parent = inner

        local gradient = Instance.new("UIGradient")
        gradient.Rotation = 90
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 90, 90)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(55, 55, 55)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 30)),
        })
        gradient.Parent = inner

        local scratches = Instance.new("Frame")
        scratches.Size = UDim2.fromScale(1, 1)
        scratches.BackgroundTransparency = 1
        scratches.ClipsDescendants = true
        scratches.Parent = inner

        local function scratch(rot, len, trans)
            local s = Instance.new("Frame")
            s.Size = UDim2.new(len, 0, 0, 1)
            s.AnchorPoint = Vector2.new(0.5, 0.5)
            s.Position = UDim2.fromScale(0.5, 0.5)
            s.Rotation = rot
            s.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            s.BackgroundTransparency = trans
            s.BorderSizePixel = 0
            s.Parent = scratches
        end
        scratch(35, 0.7, 0.88)
        scratch(-55, 0.5, 0.9)
        scratch(120, 0.4, 0.92)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Text = "0%"
        label.TextColor3 = Color3.fromRGB(235, 235, 235)
        label.Font = Enum.Font.Antique
        label.TextScaled = true
        label.Rotation = -3
        label.Parent = inner

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(0, 0, 0)
        stroke.Thickness = 1.5
        stroke.Transparency = 0.15
        stroke.Parent = label

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0.15, 0)
        padding.PaddingRight = UDim.new(0.15, 0)
        padding.PaddingTop = UDim.new(0.15, 0)
        padding.PaddingBottom = UDim.new(0.15, 0)
        padding.Parent = label

        return outer, inner, stroke, label
    end

    local generators, circles = {}, {}
    local GENERATORS_PATH = nil

      local function findGeneratorsPath()
        local map = workspace:FindFirstChild("Map")
        if map then
            local g = map:FindFirstChild("Generator") or map:FindFirstChild("Generators")
            if g then return g end
        end
        return workspace:FindFirstChild("Generator") or workspace:FindFirstChild("Generators")
    end

    local function getPart(gen)
        return gen:IsA("BasePart") and gen or gen.PrimaryPart or gen:FindFirstChildWhichIsA("BasePart")
    end

    local function refreshGenerators()
        for _, c in ipairs(circles) do
            if c.outer then c.outer:Destroy() end
        end
        circles = {}
        generators = {}

        GENERATORS_PATH = findGeneratorsPath()
        if not GENERATORS_PATH then return end

        for _, gen in ipairs(GENERATORS_PATH:GetChildren()) do
            local part = getPart(gen)
            if part then
                table.insert(generators, {gen = gen, part = part})
            end
        end

        for i = 1, #generators do
            local outer, inner, stroke, label = createCircle()
            circles[i] = {outer = outer, inner = inner, stroke = stroke, label = label}
        end
    end

    local function pathStillValid()
        if not GENERATORS_PATH or not GENERATORS_PATH.Parent then return false end
        return findGeneratorsPath() == GENERATORS_PATH
    end

    local function listStillValid()
        for _, data in ipairs(generators) do
            if not data.part or not data.part.Parent then return false end
            if not data.gen or not data.gen.Parent then return false end
        end
        return true
    end

    local RS = game:GetService("RunService")
    RS.RenderStepped:Connect(function()
        if not enabled then
            for _, c in ipairs(circles) do
                if c.outer then c.outer.Visible = false end
            end
            return
        end

        if not pathStillValid() or not listStillValid() then
            refreshGenerators()
        end

        local camPos = camera.CFrame.Position

        for i, data in ipairs(generators) do
            local circle = circles[i]
            if not circle then continue end

            local part = data.part
            if not part or not part.Parent then
                circle.outer.Visible = false
                continue
            end

            local worldPos = part.Position + Vector3.new(0, HEIGHT_OFF, 0)

            if (worldPos - camPos).Magnitude > MAX_DIST then
                circle.outer.Visible = false
                continue
            end

            local screenPos, onScreen = camera:WorldToViewportPoint(worldPos)
            if not onScreen or screenPos.Z < 0 then
                circle.outer.Visible = false
                continue
            end

            circle.outer.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)

            local completed = data.gen:GetAttribute("Completed") or false
            local progress  = data.gen:GetAttribute("RepairProgress") or 0
            local percent = math.clamp(math.floor(progress + 0.5), 0, 100)
            local targetColor = completed and GREEN_COLOR or RED_COLOR
            if completed then percent = 100 end

            circle.label.Text = percent .. "%"
            circle.outer.BackgroundColor3 = circle.outer.BackgroundColor3:Lerp(targetColor, 0.2)
            circle.stroke.Color = circle.outer.BackgroundColor3

            circle.outer.Visible = true
        end
    end)

    local api = {}

    function api.setEnabled(state)
        enabled = state
        if not enabled then
            for _, c in ipairs(circles) do
                if c.outer then c.outer.Visible = false end
            end
        else
            refreshGenerators()
        end
        return enabled
    end

    function api.toggle()
        return api.setEnabled(not enabled)
    end

    function api.enable()  api.setEnabled(true)  end
    function api.disable() api.setEnabled(false) end
    function api.isEnabled() return enabled end

    return api
end)()

-- ============================================================== PUMPKIN ESP (modules)
local PumpkinESP = (function()
    local ORANGE      = Color3.fromRGB(255, 140, 0)
    local SIZE        = 40
    local MAX_DIST    = 500
    local HEIGHT_OFF  = 3

    local enabled = false

    local camera = workspace.CurrentCamera
    local CoreGui = game:GetService("CoreGui")

    local old = CoreGui:FindFirstChild("PumpkinESP")
    if old then old:Destroy() end
    local plrGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if plrGui then
        local o = plrGui:FindFirstChild("PumpkinESP")
        if o then o:Destroy() end
    end

    local screen = Instance.new("ScreenGui")
    screen.Name = "PumpkinESP"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.DisplayOrder = 999
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local ok = pcall(function() screen.Parent = CoreGui end)
    if not ok then
        screen.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    end

    local function createMarker()
        -- Внешний круг (оранжевый ободок)
        local outer = Instance.new("Frame")
        outer.Size = UDim2.fromOffset(SIZE + 4, SIZE + 4)
        outer.AnchorPoint = Vector2.new(0.5, 0.5)
        outer.BackgroundColor3 = ORANGE
        outer.BackgroundTransparency = 0.1
        outer.BorderSizePixel = 0
        outer.Visible = false
        outer.Parent = screen

        local oc = Instance.new("UICorner")
        oc.CornerRadius = UDim.new(1, 0)
        oc.Parent = outer

        local glow = Instance.new("UIStroke")
        glow.Color = ORANGE
        glow.Thickness = 2
        glow.Transparency = 0.4
        glow.Parent = outer

        -- Внутренний тёмный диск
        local inner = Instance.new("Frame")
        inner.Size = UDim2.fromOffset(SIZE - 8, SIZE - 8)
        inner.AnchorPoint = Vector2.new(0.5, 0.5)
        inner.Position = UDim2.fromScale(0.5, 0.5)
        inner.BackgroundColor3 = Color3.fromRGB(30, 20, 10)
        inner.BackgroundTransparency = 0.1
        inner.BorderSizePixel = 0
        inner.Parent = outer

        local ic = Instance.new("UICorner")
        ic.CornerRadius = UDim.new(1, 0)
        ic.Parent = inner

        -- Иконка тыквы (просто точка/символ — можно заменить)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Text = "🎃"
        label.TextColor3 = ORANGE
        label.TextScaled = true
        label.Parent = inner

        return outer, inner, label
    end

    local pumpkins, markers = {}, {}
    local PUMPKINS_PATH = nil

    local function findPumpkinsPath()
        local map = workspace:FindFirstChild("Map")
        if map then
            local p = map:FindFirstChild("Pumpkins") or map:FindFirstChild("Pumpkin")
            if p then return p end
        end
        return workspace:FindFirstChild("Pumpkins") or workspace:FindFirstChild("Pumpkin")
    end

    local function getPart(obj)
        return obj:IsA("BasePart") and obj or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    end

    local function refreshPumpkins()
        for _, m in ipairs(markers) do
            if m.outer then m.outer:Destroy() end
        end
        markers = {}
        pumpkins = {}

        PUMPKINS_PATH = findPumpkinsPath()
        if not PUMPKINS_PATH then return end

        for _, p in ipairs(PUMPKINS_PATH:GetChildren()) do
            local part = getPart(p)
            if part then
                table.insert(pumpkins, {obj = p, part = part})
            end
        end

        for i = 1, #pumpkins do
            local outer, inner, label = createMarker()
            markers[i] = {outer = outer, inner = inner, label = label}
        end
    end

    local function pathStillValid()
        if not PUMPKINS_PATH or not PUMPKINS_PATH.Parent then return false end
        return findPumpkinsPath() == PUMPKINS_PATH
    end

       local function listStillValid()
        -- Если путь отвалился — пересобрать
        if not PUMPKINS_PATH or not PUMPKINS_PATH.Parent then return false end

        for _, data in ipairs(pumpkins) do
            -- Объект/часть удалены
            if not data.part or not data.part.Parent then return false end
            if not data.obj or not data.obj.Parent then return false end

            -- Объект вышел из папки (перемещён/сломан)
            if data.obj.Parent ~= PUMPKINS_PATH then return false end

            -- Объект невидим / отключён (сломан, но не удалён)
            if data.part.Transparency >= 0.95 then return false end
            if data.part.Parent == nil then return false end
        end
        return true
    end

    local RS = game:GetService("RunService")
    RS.RenderStepped:Connect(function()
        if not enabled then
            for _, m in ipairs(markers) do
                if m.outer then m.outer.Visible = false end
            end
            return
        end

               if not pathStillValid() or not listStillValid() then
            refreshPumpkins()
        end
        -- Если после пересбора всё ещё пусто и путь есть — попробуем позже
        if enabled and #pumpkins == 0 and PUMPKINS_PATH and #PUMPKINS_PATH:GetChildren() > 0 then
            refreshPumpkins()
        end

        local camPos = camera.CFrame.Position

               for i, data in ipairs(pumpkins) do
            local marker = markers[i]
            if not marker then continue end

            local part = data.part
            if not part or not part.Parent then
                marker.outer.Visible = false
                continue
            end

            -- Пропала из папки / сломана / невидима → спрятать маркер
            if data.obj.Parent ~= PUMPKINS_PATH
                or part.Transparency >= 0.95
                or data.obj:GetAttribute("Broken") == true
                or data.obj:GetAttribute("Destroyed") == true
            then
                marker.outer.Visible = false
                continue
            end

            local worldPos = part.Position + Vector3.new(0, HEIGHT_OFF, 0)

            if (worldPos - camPos).Magnitude > MAX_DIST then
                marker.outer.Visible = false
                continue
            end

            local screenPos, onScreen = camera:WorldToViewportPoint(worldPos)
            if not onScreen or screenPos.Z < 0 then
                marker.outer.Visible = false
                continue
            end

            marker.outer.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)

            -- Пульсация ободка
            local pulse = 0.15 + math.abs(math.sin(tick() * 3)) * 0.25
            marker.outer.BackgroundTransparency = pulse

            marker.outer.Visible = true
        end
    end)

    local api = {}

    function api.setEnabled(state)
        enabled = state
        if not enabled then
            for _, m in ipairs(markers) do
                if m.outer then m.outer.Visible = false end
            end
        else
            refreshPumpkins()
        end
        return enabled
    end

    function api.toggle() return api.setEnabled(not enabled) end
    function api.enable()  api.setEnabled(true)  end
    function api.disable() api.setEnabled(false) end
    function api.isEnabled() return enabled end

    return api
end)()

-- ============================================================== ESP GENERATOR UI
local genUIBtn = makeCard(scrlE, "Generator Progress", "Кружки с % над генераторами")
genUIBtn.MouseButton1Click:Connect(function()
    local on = GeneratorUI.toggle()
    genUIBtn.Text = on and "ON" or "OFF"
    genUIBtn.BackgroundColor3 = on and Color3.fromRGB(30,150,30) or Color3.fromRGB(180,30,30)
end)

-- ============================================================== ESP PUMPKIN
local pumpkinBtn = makeCard(scrlE, "Pumpkin ESP", "Оранжевые маркеры на тыквах")
pumpkinBtn.MouseButton1Click:Connect(function()
    local on = PumpkinESP.toggle()
    pumpkinBtn.Text = on and "ON" or "OFF"
    pumpkinBtn.BackgroundColor3 = on and Color3.fromRGB(30,150,30) or Color3.fromRGB(180,30,30)
end)

-- ============================================================== ESP RINGS
-- ============================================================== RING: PLAYER (self)
local SelfRingEnabled = false

local function selfRingRefresh()
    if not SelfRingEnabled then return end
    local me = LocalPlayer
    local role = getPlayerRoleSafe(me)
    if role ~= "Killer" then
        if not RingEngine.rings[me] then
            createRingFor(me, Color3.new(1, 1, 1))  -- белый
        end
    else
        removeRingFor(me)
    end
end

local function setSelfRing(on)
    SelfRingEnabled = on
    if on then
        selfRingRefresh()
        startRingEngine()
    else
        removeRingFor(LocalPlayer)
        if not KillerRingEnabled then stopRingEngine() end
    end
end

-- ============================================================== RING: KILLER (red)
local KillerRingEnabled = false
local killerRingTarget = nil

local function killerRingRefresh()
    if not KillerRingEnabled then return end
    local found = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if getPlayerRoleSafe(p) == "Killer" then
            found = p
            break
        end
    end
    if found ~= killerRingTarget then
        if killerRingTarget then removeRingFor(killerRingTarget) end
        killerRingTarget = found
    end
    if found and not RingEngine.rings[found] then
        createRingFor(found, Color3.fromRGB(255, 40, 40))  -- красный
    end
end

local function setKillerRing(on)
    KillerRingEnabled = on
    if on then
        killerRingRefresh()
        startRingEngine()
    else
        if killerRingTarget then
            removeRingFor(killerRingTarget)
            killerRingTarget = nil
        end
        if not SelfRingEnabled then stopRingEngine() end
    end
end

-- Обновление Killer Ring при смене персонажа/роли
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        if KillerRingEnabled then killerRingRefresh() end
    end)
end)
for _, p in ipairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        if KillerRingEnabled then killerRingRefresh() end
    end)
end
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if SelfRingEnabled then selfRingRefresh() end
    if KillerRingEnabled then killerRingRefresh() end
end)

-- Периодическая проверка ролей (раз в 2 сек)
task.spawn(function()
    while true do
        task.wait(2)
        if KillerRingEnabled then killerRingRefresh() end
        if SelfRingEnabled then selfRingRefresh() end
    end
end)

local selfRingBtn = makeCard(scrlE, "Player Ring (White)", "Белое кольцо на полу под тобой")
selfRingBtn.MouseButton1Click:Connect(function()
    SelfRingEnabled = not SelfRingEnabled
    selfRingBtn.Text = SelfRingEnabled and "ON" or "OFF"
    selfRingBtn.BackgroundColor3 = SelfRingEnabled and Color3.fromRGB(30,150,30) or Color3.fromRGB(180,30,30)
    setSelfRing(SelfRingEnabled)
end)

local killerRingBtn = makeCard(scrlE, "Killer Ring (Red)", "Красное кольцо под Killer")
killerRingBtn.MouseButton1Click:Connect(function()
    KillerRingEnabled = not KillerRingEnabled
    killerRingBtn.Text = KillerRingEnabled and "ON" or "OFF"
    killerRingBtn.BackgroundColor3 = KillerRingEnabled and Color3.fromRGB(30,150,30) or Color3.fromRGB(180,30,30)
    setKillerRing(KillerRingEnabled)
end)

-- ============================================================== Player (2 функции)

-- 1. Toggle Dash Cycle
local dashBtn = makeCard(scrlP, "Dash Cycle", "Периодический рывок (normal -> dash -> ...)")
dashBtn.MouseButton1Click:Connect(function()
    local on = dashToggle()
    dashBtn.Text = on and "ON" or "OFF"
    dashBtn.BackgroundColor3 = on and Color3.fromRGB(30,150,30) or Color3.fromRGB(180,30,30)
end)

-- 2. Normal Duration
makeNumberCard(
    scrlP,
    "Normal Duration (sec)",
    "Сколько секунд обычной скорости",
    DashConfig.normalDuration,
    0.1, 10, 0.1,
    function(v) DashConfig.normalDuration = v end
)

-- 3. Dash Duration
makeNumberCard(
    scrlP,
    "Dash Duration (sec)",
    "Сколько секунд длится рывок",
    DashConfig.dashDuration,
    0.1, 10, 0.1,
    function(v) DashConfig.dashDuration = v end
)

-- 4. Dash Speed
makeNumberCard(
    scrlP,
    "Dash Speed (studs/s)",
    "Скорость рывка. Обычная ~17",
    DashConfig.dashSpeed,
    5, 500, 1,
    function(v) DashConfig.dashSpeed = v end
)
-- ============================================================== SURVIVAL (2 функции)
local genBtn = makeCard(scrlS, "Auto Generator SkillCheck", "RISK: may not release generator after check")
genBtn.MouseButton1Click:Connect(function()
    GEN_SKILL_ENABLED = not GEN_SKILL_ENABLED
    genBtn.Text = GEN_SKILL_ENABLED and "ON" or "OFF"
    genBtn.BackgroundColor3 = GEN_SKILL_ENABLED and Color3.fromRGB(30,150,30) or Color3.fromRGB(180,30,30)
end)

local healBtn = makeCard(scrlS, "Auto Healing SkillCheck", "RISK: may not release heal after check")
healBtn.MouseButton1Click:Connect(function()
    HEAL_SKILL_ENABLED = not HEAL_SKILL_ENABLED
    healBtn.Text = HEAL_SKILL_ENABLED and "ON" or "OFF"
    healBtn.BackgroundColor3 = HEAL_SKILL_ENABLED and Color3.fromRGB(30,150,30) or Color3.fromRGB(180,30,30)
end)

-- ============================================================== КНОПКИ СЛЕВА
local scrl = Instance.new("ScrollingFrame")
scrl.Name = "scrl bar"
scrl.Size = UDim2.new(0, 200, 1, 0)
scrl.Position = UDim2.new(0, 0, 0, 0)
scrl.BackgroundColor3 = Color3.fromRGB(41, 0, 0)
scrl.BackgroundTransparency = 1
scrl.BorderSizePixel = 0
scrl.Active = true
scrl.ScrollBarThickness = 6
scrl.ScrollBarImageColor3 = Color3.fromRGB(85, 0, 0)
scrl.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrl.ScrollingDirection = Enum.ScrollingDirection.Y
scrl.ZIndex = 2
scrl.Parent = menu

local scrlCorner = Instance.new("UICorner")
scrlCorner.CornerRadius = UDim.new(0, 10)
scrlCorner.Parent = scrl

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 10)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = scrl

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.Parent = scrl

local function makeNavButton(text, target)
    local b = Instance.new("TextButton")
    b.Name = text
    b.Size = UDim2.new(1, 0, 0, 45)
    b.BackgroundColor3 = Color3.fromRGB(85, 0, 0)
    b.BackgroundTransparency = 0.6
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 15
    b.Font = Enum.Font.GothamBold
    b.ZIndex = 2
    b.Parent = scrl

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = b

    local img = Instance.new("ImageLabel")
    img.Name = "Img"
    img.Size = UDim2.new(0, 40, 1, 0)
    img.Position = UDim2.new(0, 0, 0, 0)
    img.Image = "rbxassetid://139819115920808"
    img.BackgroundTransparency = 1
    img.ScaleType = Enum.ScaleType.Fit
    img.Parent = b

    b.MouseButton1Click:Connect(function()
        Killer.Visible = false
        Survival.Visible = false
        Esp.Visible = false
        PlayerFrame.Visible = false
        Troll.Visible = false
        World.Visible = false
        Server.Visible = false
        Settings.Visible = false
        Credits.Visible = false
        target.Visible = true
    end)
end

makeNavButton("Killer", Killer)
makeNavButton("Survival", Survival)
makeNavButton("ESP", Esp)
makeNavButton("Player", PlayerFrame)
makeNavButton("Troll", Troll)
makeNavButton("World", World)
makeNavButton("Server", Server)
makeNavButton("Settings", Settings)
makeNavButton("Credits", Credits)

-- ================================================================================ end root

btn1.MouseButton1Click:Connect(function()
    root.Enabled = not root.Enabled
end)
