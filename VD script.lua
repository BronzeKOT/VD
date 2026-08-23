-- Violence District Hub by AMAKA Hub
-- Fully improved: Gen ESP, Pallet ESP, Player ESP, targeted heal, no pumpkin stuff

local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local Camera            = workspace.CurrentCamera

-- ══ AUTO GEN MODULE (optional) ═══════════════════════════════════════════════
local AutoGen = nil
local mf = ReplicatedStorage:FindFirstChild("Modules")
if mf then
    local m = mf:FindFirstChild("AutoGeneratorRepair")
    if m and m:IsA("ModuleScript") then
        local ok, r = pcall(require, m)
        if ok and type(r) == "table" then AutoGen = r end
    end
end

-- ══ REMOTES ══════════════════════════════════════════════════════════════════
local remotesRoot      = ReplicatedStorage:FindFirstChild("Remotes")
local generatorRemotes = remotesRoot and remotesRoot:FindFirstChild("Generator")
local repairEvent      = generatorRemotes and generatorRemotes:FindFirstChild("RepairEvent")
local skillCheckEvent  = generatorRemotes and generatorRemotes:FindFirstChild("SkillCheckResultEvent")
local healingRemotes   = remotesRoot and remotesRoot:FindFirstChild("Healing")
local healSkillCheck   = healingRemotes and healingRemotes:FindFirstChild("SkillCheckResultEvent")

-- ══ OWNER CHECK ══════════════════════════════════════════════════════════════
local ownerList = {
    p_serebroke8yu173   = true,
    xxxsavagexxx2019pro = true,
    xxxjordanxxxop      = true,
    landenevans2015     = true,
    gekkefries20        = true,
}
local function isOwner(n)     return ownerList[string.lower(n or "")] == true end
local function ownerPresent() for _,p in ipairs(Players:GetPlayers()) do if isOwner(p.Name) then return true end end return false end
local function shouldDisable() return ownerPresent() and not isOwner(LocalPlayer.Name) end

local function scriptDisable()
    pcall(function()
        for _,g in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
            if g:IsA("ScreenGui") then g.Enabled = false end
        end
    end)
    warn("AMAKA Hub Disabled -- owner present.")
end

if shouldDisable() then scriptDisable(); return end
Players.PlayerAdded:Connect(function(p)
    if isOwner(p.Name) and not isOwner(LocalPlayer.Name) then scriptDisable() end
end)

-- ══ HELPERS ══════════════════════════════════════════════════════════════════
local ignoreList = { landenevans2015 = true }

local function alive(i)       return i ~= nil and i.Parent ~= nil end
local function validPart(p)   return p and alive(p) and p:IsA("BasePart") end

local function zeroVel(part)
    if not part then return end
    pcall(function()
        part.AssemblyLinearVelocity = Vector3.zero
        part.Velocity               = Vector3.zero
        part.RotVelocity            = Vector3.zero
    end)
end

local function safeTeleport(cf)
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    if h then pcall(function() h:PivotTo(cf) end); task.defer(function() zeroVel(h) end) end
end

local function firstBasePart(inst)
    if not alive(inst) then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        if inst.PrimaryPart and validPart(inst.PrimaryPart) then return inst.PrimaryPart end
        return inst:FindFirstChildWhichIsA("BasePart", true)
    end
end

local function getMyHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getMyPos()
    local h = getMyHRP()
    return h and h.Position
end

-- ══ MAP / GENERATOR HELPERS ══════════════════════════════════════════════════
local function getMap()
    return workspace:FindFirstChild("Map") or workspace:FindFirstChild("Map1")
end

local function getMapName()
    local map = getMap()
    if not map then return "None" end
    local ok, attr = pcall(function() return map:GetAttribute("MapName") end)
    if ok and attr then return tostring(attr) end
    return map.Name
end

local function getGenerators()
    local map = getMap()
    if not map then return {} end
    local res = {}
    local function recurse(f)
        for _, c in ipairs(f:GetChildren()) do
            if c:IsA("Model") and string.find(c.Name:lower(),"generator") then
                table.insert(res, c)
            elseif c:IsA("Folder") or c:IsA("Model") then
                recurse(c)
            end
        end
    end
    recurse(map)
    return res
end

-- Generator point cache
local genPtsCache   = {}
local genPartsCache = {}
local genCacheConns = {}

local function buildGenCache(gen)
    if not (gen and gen:IsA("Model") and gen.Parent) then return end
    local pts, parts, seen = {}, {}, {}
    for _, name in ipairs({"GeneratorPoint","GeneratorPoint1","GeneratorPoint2","GeneratorPoint3"}) do
        local c = gen:FindFirstChild(name, true)
        if c and c:IsA("BasePart") and not seen[c] then seen[c]=true; table.insert(pts,c) end
    end
    for _, d in ipairs(gen:GetDescendants()) do
        if d:IsA("BasePart") then
            table.insert(parts, d)
            local ln = d.Name:lower()
            if (ln:find("generatorpoint") or ln:find("generator_point") or ln:find("point")) and not seen[d] then
                seen[d]=true; table.insert(pts, d)
            end
        end
    end
    if gen.PrimaryPart and not seen[gen.PrimaryPart] then
        seen[gen.PrimaryPart]=true; table.insert(pts, gen.PrimaryPart)
    end
    genPtsCache[gen]   = pts
    genPartsCache[gen] = parts
    if not genCacheConns[gen] then
        genCacheConns[gen] = {
            add = gen.DescendantAdded:Connect(function(d)    if d:IsA("BasePart") then buildGenCache(gen) end end),
            rem = gen.DescendantRemoving:Connect(function(d) if d:IsA("BasePart") then buildGenCache(gen) end end),
        }
    end
end

local function getGenPoints(gen)
    if not gen then return {} end
    if not genPtsCache[gen] then buildGenCache(gen) end
    return genPtsCache[gen] or {}
end

local function genBodyDist(gen, pos)
    local parts = genPartsCache[gen]
    if not parts then
        local best = math.huge
        for _,d in ipairs(gen:GetDescendants()) do
            if d:IsA("BasePart") then
                local ok,dd = pcall(function() return (d.Position-pos).Magnitude end)
                if ok and dd < best then best = dd end
            end
        end
        return best
    end
    local best = math.huge
    for _,d in ipairs(parts) do
        if d and d.Parent then
            local ok,dd = pcall(function() return (d.Position-pos).Magnitude end)
            if ok and dd < best then best = dd end
        end
    end
    return best
end

-- ══ ESP STATE ════════════════════════════════════════════════════════════════
local playerESPOn    = false
local genESPOn       = false
local palletESPOn    = false
local windowESPOn    = false
local hookESPOn      = false
local gateESPOn      = false

-- ══ HIGHLIGHT FACTORY ════════════════════════════════════════════════════════
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
    bg.Name          = "VD_ESP"
    bg.AlwaysOnTop   = true
    bg.Size          = UDim2.new(0, sizeX or 160, 0, sizeY or 40)
    bg.StudsOffset   = Vector3.new(0, studOff or 3, 0)
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

-- ══ PLAYER ESP ═══════════════════════════════════════════════════════════════
-- Shows: role label on head, colored highlight, distance for killers
local playerESPData = {}  -- player -> { hl, bb, lbl }
local playerESPConn = nil

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
    pcall(function() if d.hl  and alive(d.hl)  then d.hl:Destroy()  end end)
    pcall(function() if d.bb  and alive(d.bb)  then d.bb:Destroy()  end end)
    playerESPData[p] = nil
end

local function addPlayerESP(p)
    if not playerESPOn then return end
    if p == LocalPlayer or ignoreList[p.Name] then return end
    local char = p.Character
    if not (char and char:FindFirstChild("HumanoidRootPart")) then return end

    removePlayerESP(p)

    local role  = getPlayerRole(p)
    local col   = roleColor(role)
    local fill  = roleFill(role)

    -- Highlight the entire character
    local hl = makeHighlight(char, fill, Color3.new(1,1,1), char)

    -- Role label on head, always visible
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    local bb, lbl = makeBillboard(role, col, 2.8, 180, 46)
    -- Make text bigger and more visible
    lbl.TextSize  = 16
    lbl.Font      = Enum.Font.GothamBold
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

-- Heartbeat: update labels with distance
local playerESPHeartbeat = nil
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
            -- Update role in case team changed
            local role = getPlayerRole(p)
            if role ~= d.role then
                removePlayerESP(p)
                addPlayerESP(p)
                continue
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

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        if playerESPOn then task.wait(0.5); addPlayerESP(p) end
    end)
end)
Players.PlayerRemoving:Connect(function(p) removePlayerESP(p) end)

-- ══ GENERATOR ESP ════════════════════════════════════════════════════════════
local genESPData = {}  -- gen -> { hl, bb, lbl }
local genAddConn = nil

local function getGenRepairPct(gen)
    local pct = 0
    pcall(function()
        local v = gen:GetAttribute("RepairProgress") or 0
        pct = tonumber(v) or 0
        if pct >= 0 and pct <= 1.001 then pct = pct * 100 end
        pct = math.clamp(pct, 0, 100)
    end)
    return pct
end

local function getGenRepairers(gen)
    local n = 0
    pcall(function()
        n = tonumber(gen:GetAttribute("PlayersRepairingCount") or 0) or 0
    end)
    return n
end

local function genESPColor(pct)
    return Color3.fromHSV(math.clamp((pct/100)*0.33, 0, 0.33), 1, 1)
end

local function removeGenESP(gen)
    local d = genESPData[gen]
    if not d then return end
    pcall(function() if d.hl and alive(d.hl) then d.hl:Destroy() end end)
    pcall(function() if d.bb and alive(d.bb) then d.bb:Destroy() end end)
    genESPData[gen] = nil
end

local function addGenESP(gen)
    if not genESPOn then return end
    if not (alive(gen) and gen:IsA("Model")) then return end
    if genESPData[gen] and alive(genESPData[gen].bb) then return end
    removeGenESP(gen)

    local pts = getGenPoints(gen)
    local rep = pts[1] or gen.PrimaryPart or gen:FindFirstChildWhichIsA("BasePart",true)
    if not validPart(rep) then return end

    local pct = getGenRepairPct(gen)
    local hl  = makeHighlight(gen, Color3.fromRGB(255,220,30), Color3.fromRGB(255,255,200), gen)
    local bb, lbl = makeBillboard("Gen 0%", genESPColor(pct), 4, 200, 44)
    bb.Parent = rep

    genESPData[gen] = { hl=hl, bb=bb, lbl=lbl }
end

local function refreshGenESP()
    for gen, _ in pairs(genESPData) do removeGenESP(gen) end
    genESPData = {}
    if not genESPOn then return end
    for _, gen in ipairs(getGenerators()) do addGenESP(gen) end
end

-- Continuous gen label updater — removes ESP when gen hits 100%
task.spawn(function()
    while true do
        if genESPOn then
            local myPos = getMyPos()
            for gen, d in pairs(genESPData) do
                if not (alive(gen) and alive(d.bb)) then
                    removeGenESP(gen); continue
                end
                local pct = getGenRepairPct(gen)
                -- Remove ESP when generator is fully repaired
                if pct >= 100 then
                    removeGenESP(gen); continue
                end
                if d.lbl then
                    local repairers = getGenRepairers(gen)
                    local col       = genESPColor(pct)
                    local txt       = string.format("Gen %d%%", math.floor(pct+0.5))
                    if repairers > 0 then txt = txt .. string.format(" (%dp)", repairers) end
                    if myPos then
                        local dist = genBodyDist(gen, myPos)
                        if dist < math.huge then txt = txt .. string.format("  %.0f", dist) end
                    end
                    d.lbl.Text       = txt
                    d.lbl.TextColor3 = col
                end
            end
        end
        task.wait(0.25)
    end
end)

-- Listen for new generators
local function startGenListener()
    if genAddConn then return end
    genAddConn = workspace.DescendantAdded:Connect(function(d)
        if not genESPOn then return end
        if d:IsA("Model") and d.Name:lower():find("generator") then
            task.defer(function() addGenESP(d) end)
        end
    end)
end

-- ══ PALLET ESP ═══════════════════════════════════════════════════════════════
local palletESPData = {}  -- obj -> { hl, bb, lbl }

local function getPallets()
    local map = getMap()
    if not map then return {} end
    local res, seen = {}, {}

    local function addPallet(obj)
        if obj and not seen[obj] and alive(obj) then
            seen[obj] = true
            table.insert(res, obj)
        end
    end

    -- PRIMARY: workspace.Map.Pallets:GetChildren()
    -- This is the confirmed correct path from game source
    local palletsFolder = map:FindFirstChild("Pallets")
    if palletsFolder then
        for _, obj in ipairs(palletsFolder:GetChildren()) do
            -- Each child has a HumanoidRootPart
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hrp or firstBasePart(obj) then
                addPallet(obj)
            end
        end
    end

    -- FALLBACK: search entire map for anything named "Pallet" or in "Pallets" folder
    if #res == 0 then
        local function recurse(f, depth)
            if depth > 12 then return end
            for _, child in ipairs(f:GetChildren()) do
                local ln = child.Name:lower()
                if ln == "pallets" then
                    for _, obj in ipairs(child:GetChildren()) do
                        addPallet(obj)
                    end
                elseif ln:find("pallet") then
                    addPallet(child)
                elseif child:IsA("Folder") or child:IsA("Model") then
                    recurse(child, depth + 1)
                end
            end
        end
        recurse(map, 0)
    end

    return res
end

local function removePalletESP(obj)
    local d = palletESPData[obj]
    if not d then return end
    pcall(function() if d.hl and alive(d.hl) then d.hl:Destroy() end end)
    pcall(function() if d.bb and alive(d.bb) then d.bb:Destroy() end end)
    palletESPData[obj] = nil
end

local function rebuildPalletESP()
    for obj, _ in pairs(palletESPData) do removePalletESP(obj) end
    palletESPData = {}
    if not palletESPOn then return end
    for _, obj in ipairs(getPallets()) do
        if not alive(obj) then continue end
        -- Use HumanoidRootPart as anchor (confirmed from game source)
        local hrp = obj:FindFirstChild("HumanoidRootPart")
        local rep = hrp or firstBasePart(obj)
        if not validPart(rep) then continue end
        local hl      = makeHighlight(obj, Color3.fromRGB(180,110,40), Color3.fromRGB(255,200,100), obj)
        local bb, lbl = makeBillboard("Pallet", Color3.fromRGB(255,200,80), 3, 160, 36)
        bb.Parent = rep
        palletESPData[obj] = { hl=hl, bb=bb, lbl=lbl, hrp=rep }
    end
end

-- Pallet distance updater
task.spawn(function()
    while true do
        if palletESPOn then
            local myPos = getMyPos()
            if myPos then
                for obj, d in pairs(palletESPData) do
                    if not (alive(obj) and alive(d.bb)) then
                        removePalletESP(obj); continue
                    end
                    if d.lbl then
                        local anchor = (d.hrp and alive(d.hrp) and d.hrp) or d.bb.Parent
                        if anchor and validPart(anchor) then
                            local dist = (anchor.Position - myPos).Magnitude
                            d.lbl.Text = string.format("Pallet  %.0f", dist)
                        end
                    end
                end
            end
        end
        task.wait(0.3)
    end
end)

-- ══ WORLD TEXT ESP (Window/Hook/Gate) ════════════════════════════════════════
local worldESP = { Window={}, Hook={}, Gate={} }
local worldColors = {
    Window = Color3.fromRGB(255,255,255),
    Hook   = Color3.fromRGB(255,70,70),
    Gate   = Color3.fromRGB(255,220,30),
}

local function ensureWorldLabel(cat, model)
    if not alive(model) then return end
    if worldESP[cat][model] and alive(worldESP[cat][model]) then return end
    local rep = firstBasePart(model)
    if not validPart(rep) then return end
    local bb, _ = makeBillboard(cat, worldColors[cat], 3)
    bb.Parent = rep
    worldESP[cat][model] = bb
end

local function removeWorldLabel(cat, model)
    local bb = worldESP[cat][model]
    if bb then pcall(function() bb:Destroy() end) end
    worldESP[cat][model] = nil
end

local worldESPFlags = { Window=false, Hook=false, Gate=false }

task.spawn(function()
    while true do
        local map = getMap()
        if map then
            for cat, enabled in pairs(worldESPFlags) do
                if enabled then
                    for _, d in ipairs(map:GetDescendants()) do
                        if d:IsA("Model") and d.Name == cat then
                            ensureWorldLabel(cat, d)
                        end
                    end
                else
                    for m, _ in pairs(worldESP[cat]) do removeWorldLabel(cat, m) end
                end
            end
        end
        task.wait(1)
    end
end)

-- ══ LOAD UI ══════════════════════════════════════════════════════════════════
-- ══ SILENT AIM для Twist of Fate ═════════════════════════════════════════════
local silentAimOn = false
local silentAimThroughWalls = false
local silentAimConn = nil
local silentAimToolCheck = nil
local AIM_RADIUS = 50
local currentWeapon = nil

-- Проверка, держит ли игрок пистолет Twist of Fate
local function hasTwistOfFate()
    local char = LocalPlayer.Character
    if not char then return false end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return false end
    
    local toolName = tool.Name:lower()
    -- Проверяем, содержит ли название "twist of fate" или его вариации
    if toolName:find("twist") or toolName:find("fate") then
        return true, tool
    end
    
    -- Проверка через атрибуты оружия (если есть)
    local weaponId = tool:GetAttribute("WeaponId")
    if weaponId and (tostring(weaponId):find("twist") or tostring(weaponId):find("fate")) then
        return true, tool
    end
    
    return false, nil
end

-- Функция для получения ближайшего маньяка (убийцы)
local function getClosestKiller()
    local myPos = getMyPos()
    if not myPos then return nil, nil end
    
    local closestDist = math.huge
    local closestChar = nil
    local closestHRP = nil
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer or ignoreList[player.Name] then continue end
        
        -- Проверяем, является ли игрок убийцей
        local role = getPlayerRole(player)
        if role ~= "Killer" then continue end
        
        local char = player.Character
        if not char then continue end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        
        local dist = (hrp.Position - myPos).Magnitude
        if dist < closestDist and dist <= AIM_RADIUS then
            closestDist = dist
            closestChar = char
            closestHRP = hrp
        end
    end
    
    return closestChar, closestHRP, closestDist
end

-- Функция проверки видимости (луч из камеры до цели)
local function isVisible(targetPart)
    if not targetPart then return false end
    
    local origin = Camera.CFrame.Position
    local targetPos = targetPart.Position
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.IgnoreWater = true
    
    local direction = (targetPos - origin).Unit * (origin - targetPos).Magnitude
    local result = workspace:Raycast(origin, direction, raycastParams)
    
    if result then
        local hit = result.Instance
        if hit and hit:IsDescendantOf(targetPart.Parent) then
            return true
        end
        return false
    end
    
    return true
end

-- Основная функция Silent Aim
local function silentAimShoot()
    if not silentAimOn then return end
    
    -- Проверяем, что у нас пистолет Twist of Fate
    local hasGun, tool = hasTwistOfFate()
    if not hasGun then return end
    
    local _, targetHRP = getClosestKiller()
    if not targetHRP then return end
    
    -- Проверка на стены
    if not silentAimThroughWalls then
        if not isVisible(targetHRP) then
            return
        end
    end
    
    -- Создаем направление на цель
    local origin = Camera.CFrame.Position
    local targetPos = targetHRP.Position + Vector3.new(0, 1.5, 0) -- хэдшот
    
    local direction = (targetPos - origin).Unit
    
    -- Отправляем событие выстрела с измененным направлением
    pcall(function()
        -- Ищем удаленное событие для выстрела
        local weaponRemote = remotesRoot and remotesRoot:FindFirstChild("Weapon")
        if weaponRemote then
            local shootEvent = weaponRemote:FindFirstChild("ShootEvent")
            if shootEvent then
                -- Отправляем фейковый выстрел с направлением на цель
                shootEvent:FireServer(direction, targetPos)
            end
        end
        
        -- Альтернативный метод через Tool
        if tool then
            local toolRemote = tool:FindFirstChild("RemoteEvent") or tool:FindFirstChild("ShootEvent")
            if toolRemote then
                toolRemote:FireServer(direction, targetPos)
            end
        end
    end)
end

-- Подключаемся к событию выстрела
local function setupSilentAim()
    if silentAimConn then return end
    
    -- Ищем удаленное событие для выстрела
    local weaponRemote = remotesRoot and remotesRoot:FindFirstChild("Weapon")
    if weaponRemote then
        local shootEvent = weaponRemote:FindFirstChild("ShootEvent")
        if shootEvent then
            local oldFire = shootEvent.FireServer
            shootEvent.FireServer = function(self, ...)
                if silentAimOn and hasTwistOfFate() then
                    local args = {...}
                    if #args >= 2 then
                        local _, targetHRP = getClosestKiller()
                        if targetHRP then
                            if silentAimThroughWalls or isVisible(targetHRP) then
                                local origin = Camera.CFrame.Position
                                local targetPos = targetHRP.Position + Vector3.new(0, 1.5, 0)
                                local direction = (targetPos - origin).Unit
                                args[1] = direction
                                args[2] = targetPos
                            end
                        end
                    end
                    return oldFire(self, unpack(args))
                end
                return oldFire(self, ...)
            end
        end
    end
    
    -- Отслеживаем нажатие на стрельбу
    silentAimConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if not silentAimOn then return end
        if not hasTwistOfFate() then return end
        
        -- Левая кнопка мыши или клавиша R (для перезарядки/стрельбы)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.KeyCode == Enum.KeyCode.R then
            silentAimShoot()
        end
    end)
    
    -- Отслеживаем смену оружия
    if not silentAimToolCheck then
        silentAimToolCheck = LocalPlayer.CharacterAdded:Connect(function(char)
            char.ChildAdded:Connect(function(child)
                if child:IsA("Tool") and silentAimOn then
                    local name = child.Name:lower()
                    if name:find("twist") or name:find("fate") then
                        print("[Silent Aim] Detected: Twist of Fate")
                    end
                end
            end)
        end)
    end
end

local DrRay     = loadstring(game:HttpGet("https://raw.githubusercontent.com/AZYsGithub/DrRay-UI-Library/main/DrRay.lua"))()
local mainUI    = DrRay:Load("Violence District  Triden Hub", "Default")
local tabESP    = DrRay.newTab("ESP",        "rbxassetid://4483362458")
local tabTP     = DrRay.newTab("Tp/Kill",    "rbxassetid://4483362458")
local tabSkill  = DrRay.newTab("SkillCheck", "rbxassetid://4483362458")
local tabOthers = DrRay.newTab("Others",     "rbxassetid://4483362458")
local tabCreds  = DrRay.newTab("Credits",    "rbxassetid://4483362458")

-- ══ ESP TAB ══════════════════════════════════════════════════════════════════
tabESP.newToggle("Players ESP", "Highlight all players. Killer=red, Survivor=blue. Shows role + distance.", false, function(state)
    playerESPOn = state
    if state then
        rebuildPlayerESP()
        startPlayerESPHeartbeat()
    else
        rebuildPlayerESP()  -- clears when off
        stopPlayerESPHeartbeat()
    end
end)

tabESP.newToggle("Generator ESP (% + distance)", "Highlight generators with repair %, repairer count, and distance.", false, function(state)
    genESPOn = state
    if state then
        startGenListener()
        refreshGenESP()
    else
        refreshGenESP()  -- clears when off
    end
end)

tabESP.newToggle("Pallet ESP (auto map detect)", "Highlight all pallets on the map with distance.", false, function(state)
    palletESPOn = state
    rebuildPalletESP()
end)

tabESP.newToggle("Window ESP", "Show window names in world.", false, function(state)
    worldESPFlags.Window = state
    if not state then for m,_ in pairs(worldESP.Window) do removeWorldLabel("Window",m) end end
end)

tabESP.newToggle("Hook ESP", "Show hook names in world.", false, function(state)
    worldESPFlags.Hook = state
    if not state then for m,_ in pairs(worldESP.Hook) do removeWorldLabel("Hook",m) end end
end)

tabESP.newToggle("Gate ESP", "Show gate names in world (yellow).", false, function(state)
    worldESPFlags.Gate = state
    if not state then for m,_ in pairs(worldESP.Gate) do removeWorldLabel("Gate",m) end end
end)

-- ══ TP/KILL TAB ══════════════════════════════════════════════════════════════
local function getKillerPositions()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if ignoreList[p.Name] then continue end
        if p.Team and p.Team.Name:lower():find("killer") then
            local c = p.Character
            if c and c:FindFirstChild("HumanoidRootPart") then
                table.insert(out, c.HumanoidRootPart.Position)
            end
        end
    end
    return out
end

local function minKillerDist(pos)
    local best = math.huge
    for _, kp in ipairs(getKillerPositions()) do
        local d = (pos-kp).Magnitude
        if d < best then best = d end
    end
    return best
end

tabTP.newButton("TP to Farthest Incomplete Gen", "Teleport to the incomplete generator farthest from any killer.", function()
    local gens = getGenerators()
    if #gens == 0 then return end
    local best, bestScore = nil, -math.huge
    for _, gen in ipairs(gens) do
        if not alive(gen) then continue end
        -- Skip completed generators (100%)
        local pct = 0
        pcall(function()
            local v = gen:GetAttribute("RepairProgress") or 0
            pct = tonumber(v) or 0
            if pct >= 0 and pct <= 1.001 then pct = pct * 100 end
            pct = math.clamp(pct, 0, 100)
        end)
        if pct >= 100 then continue end
        -- Find rep part position
        local pts  = getGenPoints(gen)
        local part = pts[1] or gen.PrimaryPart or gen:FindFirstChildWhichIsA("BasePart")
        if not validPart(part) then continue end
        -- Score = distance from nearest killer (higher = safer)
        local score = minKillerDist(part.Position)
        if score > bestScore then
            bestScore = score
            best = part
        end
    end
    if best then
        safeTeleport(best.CFrame + Vector3.new(0,3,0))
    else
        -- All complete or no killers found, just pick any
        local gen  = gens[math.random(1,#gens)]
        local pts  = getGenPoints(gen)
        local part = pts[1] or gen.PrimaryPart or gen:FindFirstChildWhichIsA("BasePart")
        if part then safeTeleport(part.CFrame + Vector3.new(0,3,0)) end
    end
end)

tabTP.newButton("TP to Farthest Exit Lever", "Teleport to exit lever farthest from killers.", function()
    local map = getMap()
    if not map then return end
    local levers = {}
    local function recurse(f)
        for _, c in ipairs(f:GetChildren()) do
            local ln = c.Name:lower()
            if ln:find("exitlever") then
                local lp = c:FindFirstChild("Lever") or c:FindFirstChildWhichIsA("BasePart",true)
                if lp then table.insert(levers, lp) end
            elseif ln:find("exit") and c:FindFirstChild("Lever") then
                table.insert(levers, c:FindFirstChild("Lever"))
            elseif c:IsA("BasePart") and ln:find("lever") then
                table.insert(levers, c)
            elseif c:IsA("Folder") or c:IsA("Model") then
                recurse(c)
            end
        end
    end
    recurse(map)
    if #levers == 0 then return end
    local best, bestS = nil, -math.huge
    for _, l in ipairs(levers) do
        if l:IsA("BasePart") then
            local s = minKillerDist(l.Position)
            if s > bestS then bestS=s; best=l end
        end
    end
    if best then safeTeleport(CFrame.new(best.Position + Vector3.new(0,3,0))) end
end)



-- ══ SKILL CHECK TAB ══════════════════════════════════════════════════════════
local autoRepairOn   = false
local autoRepairConn = nil
local repairLast     = {}
local REPAIR_RADIUS  = 6
local REPAIR_CD      = 0.6

local function doSkillcheck(gen, part)
    if not (gen and part) then return end
    local key = tostring(gen)..tostring(part)
    local now = tick()
    if repairLast[key] and now-repairLast[key] < REPAIR_CD then return end
    repairLast[key] = now
    pcall(function() if skillCheckEvent then skillCheckEvent:FireServer("success",1,gen,part) end end)
    pcall(function() if repairEvent      then repairEvent:FireServer(gen,true) end end)
end

local function nearestGenPoint(pos, radius)
    local bestGen, bestPart, bestDist = nil, nil, math.huge
    for _, gen in ipairs(getGenerators()) do
        if not (gen and gen.Parent) then continue end
        local bodyD = genBodyDist(gen, pos)
        for _, part in ipairs(getGenPoints(gen)) do
            if part and part:IsA("BasePart") and part.Parent then
                local ok, d = pcall(function() return (part.Position-pos).Magnitude end)
                if ok and (d <= radius or bodyD <= radius) and d < bestDist then
                    bestDist=d; bestGen=gen; bestPart=part
                end
            end
        end
        if not bestPart and bodyD <= radius then
            local fp = gen.PrimaryPart or gen:FindFirstChildWhichIsA("BasePart",true)
            if fp then
                local ok,d = pcall(function() return (fp.Position-pos).Magnitude end)
                if ok and d < bestDist then bestDist=d; bestGen=gen; bestPart=fp end
            end
        end
    end
    return bestGen, bestPart
end

tabSkill.newToggle("Auto Repair & SkillCheck", "Auto perform skill check on generator you stand at.", false, function(state)
    autoRepairOn = state
    if state then
        if autoRepairConn then return end
        autoRepairConn = RunService.Heartbeat:Connect(function()
            if not autoRepairOn or shouldDisable() then return end
            local myPos = getMyPos()
            if not myPos then return end
            local gen, part = nearestGenPoint(myPos, REPAIR_RADIUS)
            if gen and part then doSkillcheck(gen, part) end
        end)
    else
        if autoRepairConn then autoRepairConn:Disconnect(); autoRepairConn=nil end
        repairLast = {}
    end
end)

-- AUTO HEAL — only heals the specific person you are standing next to and healing
-- Finds the SINGLE nearest injured survivor within range and heals only them
local autoHealOn   = false
local autoHealConn = nil
local HEAL_RADIUS  = 8  -- must be standing right next to them

tabSkill.newToggle("Auto SkillCheck (Heal)", "Auto complete heal skill check on the ONE person you are healing (nearest only).", false, function(state)
    autoHealOn = state
    if state then
        if autoHealConn then return end
        autoHealConn = RunService.Heartbeat:Connect(function()
            if not autoHealOn or shouldDisable() then return end
            local myPos = getMyPos()
            if not myPos then return end

            -- Find the single nearest injured survivor within radius
            local nearestChar, nearestDist = nil, math.huge
            for _, p in ipairs(Players:GetPlayers()) do
                if p == LocalPlayer or ignoreList[p.Name] then continue end
                local pc  = p.Character
                local hum = pc and pc:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health < hum.MaxHealth and pc:FindFirstChild("HumanoidRootPart") then
                    local d = (pc.HumanoidRootPart.Position - myPos).Magnitude
                    if d < nearestDist and d <= HEAL_RADIUS then
                        nearestDist = d
                        nearestChar = pc
                    end
                end
            end

            -- Only heal that ONE person — nobody else
            if nearestChar then
                pcall(function()
                    if healSkillCheck then
                        healSkillCheck:FireServer("success", 1, nearestChar)
                    end
                end)
            end
        end)
    else
        if autoHealConn then autoHealConn:Disconnect(); autoHealConn=nil end
    end
end)

-- SELF HEAL button (single press)
tabSkill.newButton("Heal Myself", "Press to instantly attempt to heal yourself.", function()
    local char = LocalPlayer.Character
    if not char then return end
    -- Try heal remote with self
    pcall(function() if healSkillCheck then healSkillCheck:FireServer("success",1,char) end end)
    -- Try SelfHeal / HealSelf remotes
    pcall(function()
        if healingRemotes then
            local r = healingRemotes:FindFirstChild("SelfHeal") or healingRemotes:FindFirstChild("HealSelf")
            if r then r:FireServer() end
        end
    end)
    -- Direct hum health
    pcall(function()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = hum.MaxHealth end
    end)
end)

-- ══ OTHERS TAB ═══════════════════════════════════════════════════════════════
-- ═══════════════════════════════════════════════════════════════════════════════
--  МОДИФИКАТОР ШАНСОВ ДЛЯ TWIST OF FATE (100% выстрел / 0% попасть в себя)
-- ═══════════════════════════════════════════════════════════════════════════════

local ChanceModifier = {
    Enabled = false,
    OriginalFunctions = {},
    Monitor = nil,
    Timer = nil
}

-- Поиск RemoteEvent для Twist of Fate
local function findTwistOfFateEvents()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return nil, nil end
    local items = remotes:FindFirstChild("Items")
    if not items then return nil, nil end
    local twistFolder = items:FindFirstChild("Twist of Fate")
    if not twistFolder then return nil, nil end
    local fireEvent = twistFolder:FindFirstChild("Fire")
    return fireEvent, nil
end

-- Применение модификатора
local function applyChanceModifier()
    if not ChanceModifier.Enabled then
        for event, original in pairs(ChanceModifier.OriginalFunctions) do
            if event and original then
                pcall(function() event.FireServer = original end)
            end
        end
        ChanceModifier.OriginalFunctions = {}
        return
    end
    
    local fireEvent = findTwistOfFateEvents()
    if not fireEvent then return end
    
    if not ChanceModifier.OriginalFunctions[fireEvent] then
        ChanceModifier.OriginalFunctions[fireEvent] = fireEvent.FireServer
    end
    
    fireEvent.FireServer = function(self, ...)
        local args = {...}
        local modified = false
        
        -- Меняем шансы: 1 = 100%, 0 = 0%
        if args[4] and type(args[4]) == "number" then
            args[4] = 1
            modified = true
        end
        if args[5] and type(args[5]) == "number" then
            args[5] = 0
            modified = true
        end
        
        for i = 4, #args do
            if type(args[i]) == "number" and args[i] >= 0 and args[i] <= 1 then
                if i == 4 then args[i] = 1
                elseif i == 5 then args[i] = 0 end
                modified = true
            end
        end
        
        if modified then
            return ChanceModifier.OriginalFunctions[fireEvent](self, unpack(args))
        end
        return ChanceModifier.OriginalFunctions[fireEvent](self, ...)
    end
end

-- Мониторинг выстрелов
local function startChanceMonitor()
    if ChanceModifier.Monitor then
        ChanceModifier.Monitor:Disconnect()
        ChanceModifier.Monitor = nil
    end
    if not ChanceModifier.Enabled then return end
    
    ChanceModifier.Monitor = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not ChanceModifier.Enabled then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local char = LocalPlayer.Character
            if char then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool and (tool.Name:lower():find("twist") or tool.Name:lower():find("fate")) then
                    task.spawn(applyChanceModifier)
                end
            end
        end
    end)
end

-- Функция для UI (переключатель)
local function toggleChanceModifier(state)
    ChanceModifier.Enabled = state
    
    if state then
        print("[Chance Modifier] ✅ 100% shoot / 0% self-hit ENABLED")
        applyChanceModifier()
        startChanceMonitor()
        
        if not ChanceModifier.Timer then
            ChanceModifier.Timer = RunService.Heartbeat:Connect(function()
                if ChanceModifier.Enabled then applyChanceModifier() end
            end)
        end
    else
        print("[Chance Modifier] ❌ DISABLED")
        if ChanceModifier.Monitor then
            ChanceModifier.Monitor:Disconnect()
            ChanceModifier.Monitor = nil
        end
        if ChanceModifier.Timer then
            ChanceModifier.Timer:Disconnect()
            ChanceModifier.Timer = nil
        end
        for event, original in pairs(ChanceModifier.OriginalFunctions) do
            if event and original then
                pcall(function() event.FireServer = original end)
            end
        end
        ChanceModifier.OriginalFunctions = {}
    end
end

-- КНОПКА В UI (ОТДЕЛЬНАЯ ФУНКЦИЯ)
tabOthers.newToggle("🎯 100% Shoot / 0% Self-Hit", 
    "Устанавливает 100% шанс выстрела и 0% шанс попасть в себя для Twist of Fate", 
    false, 
    function(state)
        toggleChanceModifier(state)
    end
)

-- Silent Aim настройки
tabOthers.newToggle("Silent Aim (Twist of Fate)", "Автоматическое прицеливание в маньяка при стрельбе из пистолета Twist of Fate", false, function(state)
    silentAimOn = state
    if state then
        setupSilentAim()
        print("[Silent Aim] Activated for Twist of Fate")
    else
        if silentAimConn then
            silentAimConn:Disconnect()
            silentAimConn = nil
        end
        print("[Silent Aim] Deactivated")
    end
end)

tabOthers.newToggle("Shoot Through Walls", "Разрешить стрельбу сквозь стены (отключите для честной игры)", false, function(state)
    silentAimThroughWalls = state
end)

tabOthers.newSlider("Aim Range", "Максимальная дистанция для Silent Aim", 50, 10, 150, function(value)
    AIM_RADIUS = value
end)

-- Кнопка для проверки текущего оружия (опционально)
tabOthers.newButton("Check Weapon", "Проверить, активен ли Twist of Fate", function()
    local hasGun, tool = hasTwistOfFate()
    if hasGun then
        print("[Info] You have Twist of Fate equipped!")
    else
        print("[Info] Twist of Fate NOT equipped!")
    end
end)

-- MASK GUI
local function createMaskGui()
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local ex = pg:FindFirstChild("MaskGui")
    if ex then ex.Enabled = true; return end

    local sg = Instance.new("ScreenGui")
    sg.Name = "MaskGui"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.Parent = pg

    local f = Instance.new("Frame")
    f.Size = UDim2.new(0,200,0,290); f.Position = UDim2.new(0.5,-100,0.5,-145)
    f.BackgroundColor3 = Color3.fromRGB(28,28,28); f.Active = true; f.Draggable = true; f.Parent = sg

    local t = Instance.new("TextLabel")
    t.Size=UDim2.new(1,-35,0,30); t.Text="Masks"; t.BackgroundTransparency=1
    t.TextColor3=Color3.new(1,1,1); t.Font=Enum.Font.GothamBold; t.TextScaled=true; t.Parent=f

    local x = Instance.new("TextButton")
    x.Size=UDim2.new(0,30,0,30); x.Position=UDim2.new(1,-33,0,0); x.Text="X"
    x.BackgroundColor3=Color3.fromRGB(200,50,50); x.TextColor3=Color3.new(1,1,1)
    x.Font=Enum.Font.GothamBold; x.TextSize=16; x.Parent=f
    x.MouseButton1Click:Connect(function() sg.Enabled=false end)

    local masks = {
        {n="Richard",  d="Default"},   {n="Tony",    d="Strength"},
        {n="Brandon",  d="Speed"},      {n="Jake",    d="Lunge"},
        {n="Richter",  d="Stealth"},    {n="Graham",  d="Vault"},
        {n="Alex",     d="Chainsaw"},
    }
    for i, m in ipairs(masks) do
        local b = Instance.new("TextButton")
        b.Size=UDim2.new(1,-12,0,30); b.Position=UDim2.new(0,6,0,32+(i-1)*33)
        b.BackgroundColor3=Color3.fromRGB(45,45,45); b.TextColor3=Color3.new(1,1,1)
        b.Font=Enum.Font.Gotham; b.Text=m.n.." - "..m.d; b.Parent=f
        b.MouseButton1Click:Connect(function()
            pcall(function()
                local ap = remotesRoot and remotesRoot:FindFirstChild("Killers")
                    and remotesRoot.Killers:FindFirstChild("Masked")
                    and remotesRoot.Killers.Masked:FindFirstChild("Activatepower")
                if ap then ap:FireServer(m.n) end
            end)
        end)
    end
end

tabOthers.newButton("Show Masks GUI", "Open mask selector.", function() createMaskGui() end)

-- FOV GUI
local function createFOVGui()
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local ex = pg:FindFirstChild("NullFOVGui")
    if ex then ex.Enabled = true; return end

    local sg = Instance.new("ScreenGui")
    sg.Name="NullFOVGui"; sg.ResetOnSpawn=false; sg.Parent=pg

    local f = Instance.new("Frame")
    f.Size=UDim2.new(0,260,0,110); f.Position=UDim2.new(0,60,0,60)
    f.BackgroundColor3=Color3.fromRGB(35,35,35); f.BorderSizePixel=0
    f.Active=true; f.Draggable=true; f.Parent=sg

    local t = Instance.new("TextLabel")
    t.Text="FOV  AMAKA Hub"; t.Size=UDim2.new(1,-35,0,30); t.BackgroundTransparency=1
    t.TextColor3=Color3.new(1,1,1); t.Font=Enum.Font.GothamBold; t.TextSize=18; t.Parent=f

    local xb = Instance.new("TextButton")
    xb.Text="X"; xb.Size=UDim2.new(0,30,0,30); xb.Position=UDim2.new(1,-33,0,0)
    xb.BackgroundColor3=Color3.fromRGB(200,50,50); xb.TextColor3=Color3.new(1,1,1)
    xb.Font=Enum.Font.GothamBold; xb.TextSize=16; xb.Parent=f
    xb.MouseButton1Click:Connect(function() sg.Enabled=false end)

    local box = Instance.new("TextBox")
    box.PlaceholderText="FOV (1-150)"; box.Text=tostring(math.floor(Camera.FieldOfView))
    box.Size=UDim2.new(0.65,0,0,34); box.Position=UDim2.new(0.04,0,0,38)
    box.BackgroundColor3=Color3.fromRGB(55,55,55); box.TextColor3=Color3.new(1,1,1)
    box.Font=Enum.Font.Gotham; box.TextSize=16; box.Parent=f

    local btn = Instance.new("TextButton")
    btn.Text="Set"; btn.Size=UDim2.new(0.25,0,0,34); btn.Position=UDim2.new(0.71,0,0,38)
    btn.BackgroundColor3=Color3.fromRGB(0,160,255); btn.TextColor3=Color3.new(1,1,1)
    btn.Font=Enum.Font.GothamBold; btn.TextSize=16; btn.Parent=f
    btn.MouseButton1Click:Connect(function()
        local v = tonumber(box.Text)
        if v and v >= 1 and v <= 150 then
            Camera.FieldOfView = v
        else
            local prev = box.Text
            box.Text = "1-150 only!"
            task.delay(0.8, function() box.Text = tostring(math.floor(Camera.FieldOfView)) end)
        end
    end)

    local hint = Instance.new("TextLabel")
    hint.Text="Press F to toggle"; hint.Size=UDim2.new(1,0,0,22); hint.Position=UDim2.new(0,0,0,80)
    hint.BackgroundTransparency=1; hint.TextColor3=Color3.fromRGB(160,160,160)
    hint.Font=Enum.Font.Gotham; hint.TextSize=13; hint.Parent=f

    UserInputService.InputBegan:Connect(function(input, gp)
        if not gp and input.KeyCode == Enum.KeyCode.F then sg.Enabled = not sg.Enabled end
    end)
end

tabOthers.newButton("Show FOV GUI", "Open FOV window. Press F to toggle.", function() createFOVGui() end)



-- ANTI LAG
tabOthers.newButton("Anti Lag (Lower Graphics)", "Reduce graphics quality to minimum to improve FPS.", function()
    local lighting = game:GetService("Lighting")
    local settings = UserSettings():GetService("UserGameSettings")
    -- Lower graphics quality
    pcall(function() settings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel01 end)
    -- Disable expensive lighting effects
    pcall(function()
        lighting.GlobalShadows    = false
        lighting.FogEnd           = 9e9
        lighting.FogStart         = 9e9
        lighting.Brightness       = 1
    end)
    -- Remove all local lighting effects
    pcall(function()
        for _, child in ipairs(lighting:GetChildren()) do
            if child:IsA("BlurEffect") or child:IsA("DepthOfFieldEffect")
                or child:IsA("SunRaysEffect") or child:IsA("ColorCorrectionEffect")
                or child:IsA("BloomEffect") then
                child.Enabled = false
            end
        end
    end)
    -- Lower render distance / quality via render settings
    pcall(function()
        local rs = settings:FindFirstChild("RenderSettings") or game:GetService("RenderSettings")
        if rs then
            if rs.QualityLevel then rs.QualityLevel = 1 end
            if rs.MeshPartDetailLevel then rs.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01 end
        end
    end)
    -- Disable decorations on terrain
    pcall(function()
        workspace.Terrain.Decoration = false
    end)
    warn("AMAKA Hub Anti-lag applied: graphics lowered to minimum.")
end)

-- ══ CREDITS ══════════════════════════════════════════════════════════════════
tabCreds.newLabel("Script by @KOTIKTOP4")
tabCreds.newLabel("UI Library by KOT")
tabCreds.newLabel("Discord: dont have")
tabCreds.newLabel("Improved by AMAKA team")

-- ══ CHARACTER / MAP RESPAWN HANDLING ═════════════════════════════════════════
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if playerESPOn    then rebuildPlayerESP()  end
    if genESPOn       then refreshGenESP()     end
    if palletESPOn    then rebuildPalletESP()  end
end)

workspace.ChildAdded:Connect(function(ch)
    if ch.Name == "Map" or ch.Name == "Map1" then
        task.wait(2)  -- wait for map to fully load
        -- Refresh ALL active ESPs when a new map is detected
        if playerESPOn  then rebuildPlayerESP()  end
        if genESPOn     then refreshGenESP()     end
        if palletESPOn  then rebuildPalletESP()  end
        -- Re-register world ESP roots
        for cat, enabled in pairs(worldESPFlags) do
            if enabled then
                for m, _ in pairs(worldESP[cat]) do removeWorldLabel(cat, m) end
            end
        end
    end
end)

-- Anti-fling / walkspeed fix
RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if hum.PlatformStand then pcall(function() hum.PlatformStand = false end) end
        if hum.WalkSpeed == 0 then pcall(function() hum.WalkSpeed = 16 end) end
    end
end)
