--Made By Unemployedperson on discord

-- ── SERVICES ──────────────────────────────────────
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService   = game:GetService("TweenService")
local Stats          = game:GetService("Stats")
local Lighting       = game:GetService("Lighting")
local HttpService    = game:GetService("HttpService")
local CoreGui        = game:GetService("CoreGui")

local lp     = Players.LocalPlayer
local player = lp   -- alias konsisten

-- getconnections (dipakai Auto Steal)
local getconnections = getconnections
    or (syn and syn.get_signal_cons)
    or get_signal_cons
    or getconnects

-- isfile / readfile / writefile (config)
local isfile    = isfile    or (syn and syn.isfile)
local readfile  = readfile  or (syn and syn.readfile)
local writefile = writefile or (syn and syn.writefile)

-- ── GLOBAL CHARACTER REFS ─────────────────────────
local character, hrp, hum

-- ── FEATURE FLAGS ─────────────────────────────────
local infiniteJumpEnabled = false
local noWalkEnabled       = false
local savedAnimate        = nil
local autoWalkEnabled     = false
local walkGui             = nil
local autoWalkTarget      = nil
local autoWalkWaypoints   = nil
local noClipEnabled       = false

-- ── UI Position memory ─────────────────────────────
local uiPositions = {
    speedCustomizer = nil,
    autoWalk        = nil,
    lockGui         = nil,
    batTeleport     = nil,
    tpGui           = nil,
    floatGui        = nil,
}

-- ── UI Lock flag (set by "Lock UI" toggle in Settings) ────────
local uiLocked = false

-- ── Shared manual-drag helper ─────────────────────────────────
-- makeDraggable(frame, onSave, dragHandle?)
-- dragHandle = the hit-zone for drag initiation (defaults to frame).
-- Detection uses UserInputService.InputBegan + an AbsolutePosition bounds
-- check so that TextButtons covering the entire frame can never block it.
local function makeDraggable(frame, onSave, dragHandle)
    local handle = dragHandle or frame
    local dragging  = false
    local dragStart = Vector3.new()
    local startPos

    -- Use UIS so the check fires even when a TextButton sits on top
    UserInputService.InputBegan:Connect(function(inp, _gp)
        if uiLocked then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local mp  = inp.Position
        local abs = handle.AbsolutePosition
        local sz  = handle.AbsoluteSize
        if mp.X >= abs.X and mp.X <= abs.X + sz.X
        and mp.Y >= abs.Y and mp.Y <= abs.Y + sz.Y then
            dragging  = true
            dragStart = mp
            startPos  = frame.Position
        end
    end)

    -- Global mouse-move keeps drag working after cursor leaves handle
    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then
            local delta = inp.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                if onSave then
                    task.defer(function() onSave(frame.AbsolutePosition) end)
                end
            end
        end
    end)
end

-- ── Dedicated UI Position Config ───────────────────
local UI_POS_FILE = "VH_UIPositions.json"

local function saveUIPositions()
    pcall(function()
        writefile(UI_POS_FILE, HttpService:JSONEncode(uiPositions))
    end)
end

local function loadUIPositions()
    pcall(function()
        local ok, raw = pcall(readfile, UI_POS_FILE)
        if not ok or not raw or raw == "" then return end
        local data = HttpService:JSONDecode(raw)
        for k, v in pairs(data) do
            uiPositions[k] = v
        end
    end)
end

loadUIPositions()

local function hookDragSave(element, posKey)
    local lastSave = 0
    local function doSave()
        local ap = element.AbsolutePosition
        uiPositions[posKey] = {x = ap.X, y = ap.Y}
        pcall(saveUIPositions)
    end
    element:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
        local now = tick()
        if now - lastSave > 0.15 then
            lastSave = now
            doSave()
        end
    end)
    element.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            task.defer(doSave)
        end
    end)
end

-- =====================================================
-- OPTIMIZER FPS
-- =====================================================
local optimizerEnabled = false
local savedLighting    = {}
local optimized        = {}

local function enableOptimizer()
    if optimizerEnabled then return end
    optimizerEnabled = true
    savedLighting = {
        GlobalShadows           = Lighting.GlobalShadows,
        FogStart                = Lighting.FogStart,
        FogEnd                  = Lighting.FogEnd,
        Brightness              = Lighting.Brightness,
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale= Lighting.EnvironmentSpecularScale
    }
    Lighting.GlobalShadows = false; Lighting.FogStart = 0; Lighting.FogEnd = 1e9
    Lighting.Brightness = 1; Lighting.EnvironmentDiffuseScale = 0
    Lighting.EnvironmentSpecularScale = 0
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            optimized[v] = {v.Material, v.Reflectance}
            v.Material = Enum.Material.Plastic; v.Reflectance = 0
        elseif v:IsA("Decal") or v:IsA("Texture") then
            optimized[v] = v.Transparency; v.Transparency = 1
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail")
            or v:IsA("Smoke") or v:IsA("Fire") then
            optimized[v] = v.Enabled; v.Enabled = false
        end
    end
end

local function disableOptimizer()
    if not optimizerEnabled then return end
    optimizerEnabled = false
    for k,v in pairs(savedLighting) do Lighting[k] = v end
    for obj,val in pairs(optimized) do
        if obj and obj.Parent then
            if typeof(val) == "table" then
                obj.Material = val[1]; obj.Reflectance = val[2]
            elseif typeof(val) == "boolean" then
                obj.Enabled = val
            else
                obj.Transparency = val
            end
        end
    end
    optimized = {}
end

-- =====================================================

-- =====================================================
-- ANTI FPS DEVOURER
-- =====================================================
local ANTI_FPS_DEVOURER = {enabled=false, connections={}, hiddenAccessories={}}

local function removeAccessory(acc)
    if not ANTI_FPS_DEVOURER.hiddenAccessories[acc] then
        ANTI_FPS_DEVOURER.hiddenAccessories[acc] = acc.Parent
        acc.Parent = nil
    end
end
function enableAntiFPSDevourer()
    if ANTI_FPS_DEVOURER.enabled then return end
    ANTI_FPS_DEVOURER.enabled = true
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Accessory") then removeAccessory(obj) end
    end
    local c = workspace.DescendantAdded:Connect(function(obj)
        if ANTI_FPS_DEVOURER.enabled and obj:IsA("Accessory") then removeAccessory(obj) end
    end)
    table.insert(ANTI_FPS_DEVOURER.connections, c)
end
function disableAntiFPSDevourer()
    if not ANTI_FPS_DEVOURER.enabled then return end
    ANTI_FPS_DEVOURER.enabled = false
    for _, conn in ipairs(ANTI_FPS_DEVOURER.connections) do
        if typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end
    end
    ANTI_FPS_DEVOURER.connections = {}
    for acc, orig in pairs(ANTI_FPS_DEVOURER.hiddenAccessories) do
        if acc then acc.Parent = orig end
    end
    ANTI_FPS_DEVOURER.hiddenAccessories = {}
end

-- =====================================================
-- MELEE AIMBOT
-- =====================================================
local MELEE_RANGE       = 45
local MELEE_ONLY_ENEMIES = true
local meleeEnabled      = false
local meleeConnection
local meleeAlignOrientation
local meleeAttachment

local function isValidMeleeTarget(humanoid, rootPart)
    if not (humanoid and rootPart) then return false end
    if humanoid.Health <= 0 then return false end
    if MELEE_ONLY_ENEMIES then
        local tp = Players:GetPlayerFromCharacter(humanoid.Parent)
        if not tp or tp == lp then return false end
    end
    return true
end

local function getClosestMeleeTarget(hrpRef)
    local closest; local minDist = MELEE_RANGE
    for _, p in ipairs(Players:GetPlayers()) do
        if p == lp then continue end
        local ch = p.Character; if not ch then continue end
        local tHrp = ch:FindFirstChild("HumanoidRootPart")
        local tHum = ch:FindFirstChildOfClass("Humanoid")
        if isValidMeleeTarget(tHum, tHrp) then
            local d = (tHrp.Position - hrpRef.Position).Magnitude
            if d < minDist then minDist = d; closest = tHrp end
        end
    end
    return closest
end

local function createMeleeAimbot(char)
    local hrpM = char:WaitForChild("HumanoidRootPart", 8)
    local humM = char:WaitForChild("Humanoid", 8)
    if not (hrpM and humM) then return end
    if meleeAlignOrientation then pcall(function() meleeAlignOrientation:Destroy() end) end
    if meleeAttachment then pcall(function() meleeAttachment:Destroy() end) end
    meleeAttachment = Instance.new("Attachment"); meleeAttachment.Parent = hrpM
    meleeAlignOrientation = Instance.new("AlignOrientation")
    meleeAlignOrientation.Attachment0 = meleeAttachment
    meleeAlignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    meleeAlignOrientation.RigidityEnabled = true
    meleeAlignOrientation.MaxTorque = 100000
    meleeAlignOrientation.Responsiveness = 200
    meleeAlignOrientation.Parent = hrpM
    if meleeConnection then meleeConnection:Disconnect() end
    meleeConnection = RunService.RenderStepped:Connect(function()
        if not char.Parent or not meleeEnabled then return end
        local target = getClosestMeleeTarget(hrpM)
        if target then
            humM.AutoRotate = false; meleeAlignOrientation.Enabled = true
            local tp = Vector3.new(target.Position.X, hrpM.Position.Y, target.Position.Z)
            meleeAlignOrientation.CFrame = CFrame.lookAt(hrpM.Position, tp)
        else
            meleeAlignOrientation.Enabled = false; humM.AutoRotate = true
        end
    end)
end

local function disableMeleeAimbot()
    meleeEnabled = false
    if meleeConnection then meleeConnection:Disconnect(); meleeConnection = nil end
    if meleeAlignOrientation then
        meleeAlignOrientation.Enabled = false
        pcall(function() meleeAlignOrientation:Destroy() end); meleeAlignOrientation = nil
    end
    if character and character:FindFirstChild("Humanoid") then
        character.Humanoid.AutoRotate = true
    end
    if meleeAttachment then pcall(function() meleeAttachment:Destroy() end); meleeAttachment = nil end
end

-- =====================================================
-- BAT TELEPORT
-- =====================================================
local batTeleportEnabled    = false
local batTeleportConnections = {}
local batIsTeleporting      = false
local batSelectedSide       = "B"
local batTeleportGui        = nil
local _batStartWalk         = nil   -- assigned after startPostTpWalk is defined
local _batOnWalkStart       = nil   -- assigned by createBatTeleportGui
local _batOnWalkEnd         = nil   -- assigned by createBatTeleportGui

local BAT_SEQ_A = {
    tp1   = Vector3.new(-470, -7, 96),
    tp2   = Vector3.new(-483, -7, 98),
}
local BAT_SEQ_B = {
    tp1   = Vector3.new(-470, -7, 24),
    tp2   = Vector3.new(-483, -7, 24),
}

local MARKER_A = {x=-470, y=-7, z=96}
local MARKER_B = {x=-470, y=-7, z=24}

local batMarkerFolder = nil
local function rebuildBatMarkers()
    if batMarkerFolder then pcall(function() batMarkerFolder:Destroy() end) end
    batMarkerFolder = Instance.new("Folder")
    batMarkerFolder.Name = "BatTeleportMarkers_VH"; batMarkerFolder.Parent = workspace
    local function mkMark(pt, lbl, col)
        local pole = Instance.new("Part")
        pole.Size = Vector3.new(0.2,7,0.2)
        pole.Position = Vector3.new(pt.x, pt.y+3.5, pt.z)
        pole.Anchored = true; pole.CanCollide = false; pole.CastShadow = false
        pole.Material = Enum.Material.SmoothPlastic; pole.Color = col
        pole.Parent = batMarkerFolder
        local sphere = Instance.new("Part"); sphere.Shape = Enum.PartType.Ball
        sphere.Size = Vector3.new(2.5,2.5,2.5)
        sphere.Position = Vector3.new(pt.x, pt.y+3, pt.z)
        sphere.Anchored = true; sphere.CanCollide = false; sphere.CastShadow = false
        sphere.Material = Enum.Material.SmoothPlastic; sphere.Color = col
        sphere.Transparency = 0.15; sphere.Parent = batMarkerFolder
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0,52,0,22); bb.StudsOffset = Vector3.new(0,3,0)
        bb.AlwaysOnTop = true; bb.Parent = sphere
        local bg = Instance.new("Frame"); bg.Size = UDim2.new(1,0,1,0)
        bg.BackgroundColor3 = Color3.fromRGB(5,5,5); bg.BorderSizePixel = 0; bg.Parent = bb
        Instance.new("UICorner",bg).CornerRadius = UDim.new(0,4)
        local bgS = Instance.new("UIStroke",bg); bgS.Color = col; bgS.Thickness = 1.5
        local lbEl = Instance.new("TextLabel"); lbEl.Size = UDim2.new(1,0,1,0)
        lbEl.BackgroundTransparency = 1; lbEl.Text = lbl; lbEl.TextColor3 = col
        lbEl.Font = Enum.Font.GothamBold; lbEl.TextSize = 11; lbEl.Parent = bg
    end
    mkMark(MARKER_A, "BAT-A", Color3.fromRGB(255,80,80))
    mkMark(MARKER_B, "BAT-B", Color3.fromRGB(80,180,255))
end
rebuildBatMarkers()

local BAT_TELEPORT_COOLDOWN = 3
local lastBatTeleportTime   = 0
local BAT_HIT_STATES = {
    [Enum.HumanoidStateType.Ragdoll]     = true,
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Physics]     = true,
    [Enum.HumanoidStateType.GettingUp]   = true,
}

local function clearRagdollConstraints(char)
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("BallSocketConstraint") or
           (desc:IsA("Attachment") and tostring(desc.Name):find("RagdollAttachment")) then
            pcall(function() desc:Destroy() end)
        end
    end
end

local function resetRagdollState(char, humR, root)
    clearRagdollConstraints(char)
    pcall(function()
        local now = workspace:GetServerTimeNow()
        lp:SetAttribute("RagdollEndTime", now)
    end)
    if humR and humR.Health > 0 then
        pcall(function() humR:ChangeState(Enum.HumanoidStateType.Running) end)
    end
    pcall(function()
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.Anchored = false
    end)
end

local function doTeleport(char)
    if not batTeleportEnabled or batIsTeleporting then return end
    local now = tick()
    if (now - lastBatTeleportTime) < BAT_TELEPORT_COOLDOWN then return end
    batIsTeleporting = true; lastBatTeleportTime = now
    task.spawn(function()
        local root = char:FindFirstChild("HumanoidRootPart")
        local humT = char:FindFirstChildOfClass("Humanoid")
        if not root or not humT then batIsTeleporting = false; return end
        resetRagdollState(char, humT, root)
        task.wait(0.08)
        if not char.Parent or not root.Parent then batIsTeleporting = false; return end

        local seq = (batSelectedSide == "A") and BAT_SEQ_A or BAT_SEQ_B
        root:PivotTo(CFrame.new(seq.tp1))
        task.wait(0.2)
        if not char.Parent then batIsTeleporting = false; return end
        root:PivotTo(CFrame.new(seq.tp2))
        batIsTeleporting = false
        -- walk to next waypoints (same as manual TP)
        if _batStartWalk then _batStartWalk(batSelectedSide) end
        if _batOnWalkStart then _batOnWalkStart() end
    end)
end

local function isRagdolledByAttribute()
    local endTime = lp:GetAttribute("RagdollEndTime")
    if type(endTime) ~= "number" then return false end
    local ok, sn = pcall(function() return workspace:GetServerTimeNow() end)
    if not ok then return false end
    return (endTime - sn) > 0
end

local function setupBatTeleport(char)
    for _, conn in ipairs(batTeleportConnections) do
        if typeof(conn) == "RBXScriptConnection" then pcall(function() conn:Disconnect() end) end
    end
    batTeleportConnections = {}; batIsTeleporting = false
    if not batTeleportEnabled then return end

    local humBT = char:WaitForChild("Humanoid", 8)
    if not humBT then return end

    local sc = humBT.StateChanged:Connect(function(_, newState)
        if not batTeleportEnabled then return end
        if not BAT_HIT_STATES[newState] then return end
        doTeleport(char)
    end)
    table.insert(batTeleportConnections, sc)
end

local function disableBatTeleport()
    batTeleportEnabled = false; batIsTeleporting = false
    for _, conn in ipairs(batTeleportConnections) do
        if typeof(conn) == "RBXScriptConnection" then pcall(function() conn:Disconnect() end) end
    end
    batTeleportConnections = {}
end

-- =====================================================
-- ANTI RAGDOLL 1
-- =====================================================
local antiRagdollMode     = nil
local ragdollConnections  = {}
local cachedCharData      = {}

local function cacheCharacterData()
    local char = lp.Character; if not char then return false end
    local humC = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not humC or not root then return false end
    cachedCharData = {
        character = char, humanoid = humC, root = root,
        originalWalkSpeed = humC.WalkSpeed,
        originalJumpPower = humC.JumpPower,
        isFrozen = false
    }
    return true
end

local function disconnectAllRagdoll()
    for _, conn in ipairs(ragdollConnections) do
        if typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    ragdollConnections = {}
end

local function isRagdolled()
    if not cachedCharData.humanoid then return false end
    local humR = cachedCharData.humanoid
    local st = humR:GetState()
    if st == Enum.HumanoidStateType.Physics
    or st == Enum.HumanoidStateType.Ragdoll
    or st == Enum.HumanoidStateType.FallingDown then return true end
    local endTime = lp:GetAttribute("RagdollEndTime")
    if endTime then
        local ok, now = pcall(function() return workspace:GetServerTimeNow() end)
        if ok and (endTime - now) > 0 then return true end
    end
    return false
end

local function removeRagdollConstraints()
    if not cachedCharData.character then return end
    for _, desc in ipairs(cachedCharData.character:GetDescendants()) do
        if desc:IsA("BallSocketConstraint") or
           (desc:IsA("Attachment") and desc.Name:find("RagdollAttachment")) then
            pcall(function() desc:Destroy() end)
        end
    end
end

local function forceExitRagdoll()
    if not cachedCharData.humanoid or not cachedCharData.root then return end
    local humF = cachedCharData.humanoid
    local rootF = cachedCharData.root
    pcall(function()
        local now = workspace:GetServerTimeNow()
        lp:SetAttribute("RagdollEndTime", now)
    end)
    if humF.Health > 0 then humF:ChangeState(Enum.HumanoidStateType.Running) end
    rootF.Anchored = false
    rootF.AssemblyLinearVelocity  = Vector3.zero
    rootF.AssemblyAngularVelocity = Vector3.zero
end

local function antiRagdollLoop()
    while antiRagdollMode do
        task.wait()
        if isRagdolled() then removeRagdollConstraints(); forceExitRagdoll() end
        local cam = workspace.CurrentCamera
        if cam and cachedCharData.humanoid then
            if cam.CameraSubject ~= cachedCharData.humanoid then
                cam.CameraSubject = cachedCharData.humanoid
            end
        end
    end
end

-- =====================================================
-- ANTI RAGDOLL 2
-- =====================================================
local antiRagdoll2Enabled = false
local antiRagdoll2Conn    = nil

local function startAntiRagdoll2()
    if antiRagdoll2Conn then return end
    antiRagdoll2Conn = RunService.Heartbeat:Connect(function()
        if not antiRagdoll2Enabled then return end
        local char = lp.Character; if not char then return end
        local humV = char:FindFirstChildOfClass("Humanoid")
        local rootV = char:FindFirstChild("HumanoidRootPart")
        if humV then
            local st = humV:GetState()
            if st == Enum.HumanoidStateType.Physics
            or st == Enum.HumanoidStateType.Ragdoll
            or st == Enum.HumanoidStateType.FallingDown then
                humV:ChangeState(Enum.HumanoidStateType.Running)
                workspace.CurrentCamera.CameraSubject = humV
                pcall(function()
                    local PM = lp.PlayerScripts:FindFirstChild("PlayerModule")
                    if not PM then return end
                    local CM = PM:FindFirstChild("ControlModule")
                    if CM then
                        local C = require(CM)
                        if C and C.Enable then C:Enable() end
                    end
                end)
                if rootV then
                    pcall(function()
                        rootV.Velocity    = Vector3.new(0,0,0)
                        rootV.RotVelocity = Vector3.new(0,0,0)
                    end)
                end
            end
        end
        if char then
            for _, obj in ipairs(char:GetDescendants()) do
                pcall(function()
                    if obj:IsA("Motor6D") and obj.Enabled == false then
                        obj.Enabled = true
                    end
                end)
            end
        end
    end)
end

local function stopAntiRagdoll2()
    antiRagdoll2Enabled = false
    if antiRagdoll2Conn then antiRagdoll2Conn:Disconnect(); antiRagdoll2Conn = nil end
end

local function _enableAR1()
    disconnectAllRagdoll()
    if not cacheCharacterData() then return end
    antiRagdollMode = "v1"
    local cc = lp.CharacterAdded:Connect(function()
        task.wait(0.5)
        if antiRagdollMode then cacheCharacterData() end
    end)
    table.insert(ragdollConnections, cc)
    task.spawn(antiRagdollLoop)
end

local function _disableAR1()
    antiRagdollMode = nil
    disconnectAllRagdoll()
    cachedCharData = {}
end

-- =====================================================
-- NO CLIP
-- =====================================================
local noClipConn = nil

local function enableNoClip()
    if noClipConn then return end
    noClipConn = RunService.Stepped:Connect(function()
        if not noClipEnabled then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lp then
                local pChar = plr.Character
                if pChar then
                    for _, part in ipairs(pChar:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end
        end
    end)
end

local function disableNoClip()
    noClipEnabled = false
    if noClipConn then noClipConn:Disconnect(); noClipConn = nil end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp then
            local pChar = plr.Character
            if pChar then
                for _, part in ipairs(pChar:GetDescendants()) do
                    if part:IsA("BasePart") then
                        pcall(function() part.CanCollide = true end)
                    end
                end
            end
        end
    end
end

-- =====================================================
-- AUTO STEAL
-- =====================================================
local autoStealEnabled  = false
local autoStealConn     = nil
local isStealing        = false
local stealStartTime    = nil
local StealData         = {}
local progressConnection = nil
local STEAL_RADIUS      = 9
local STEAL_DURATION    = 0.2
local grabRadius        = 9

local function isMyPlotByName(pn)
    local plots = workspace:FindFirstChild("Plots"); if not plots then return false end
    local plot = plots:FindFirstChild(pn); if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign"); if not sign then return false end
    local yb = sign:FindFirstChild("YourBase")
    if yb and yb:IsA("BillboardGui") then return yb.Enabled == true end
    return false
end

local function findNearestPrompt()
    local char = lp.Character
    local localHrp = char and char:FindFirstChild("HumanoidRootPart")
    if not localHrp then return nil end
    local plots = workspace:FindFirstChild("Plots"); if not plots then return nil end
    local np, nd, nn = nil, math.huge, nil
    for _, plot in ipairs(plots:GetChildren()) do
        if isMyPlotByName(plot.Name) then continue end
        local podiums = plot:FindFirstChild("AnimalPodiums"); if not podiums then continue end
        for _, pod in ipairs(podiums:GetChildren()) do
            pcall(function()
                local base = pod:FindFirstChild("Base")
                local spawn = base and base:FindFirstChild("Spawn")
                if spawn then
                    local dist = (spawn.Position - localHrp.Position).Magnitude
                    if dist < nd and dist <= grabRadius then
                        local att = spawn:FindFirstChild("PromptAttachment")
                        if att then
                            for _, ch in ipairs(att:GetChildren()) do
                                if ch:IsA("ProximityPrompt") then
                                    np, nd, nn = ch, dist, pod.Name; break
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
    return np, nd, nn
end

local progressBarBg, progressFill

local function resetBar(hide)
    if progressFill then progressFill.Size = UDim2.new(0,0,1,0) end
end

local function executeSteal(prompt, name)
    if isStealing then
        if stealStartTime and (tick() - stealStartTime) > (STEAL_DURATION * 3 + 1) then
            isStealing = false; stealStartTime = nil
            StealData[prompt] = nil
        else
            return
        end
    end
    if not prompt or not prompt.Parent then return end

    if not StealData[prompt] then
        StealData[prompt] = {hold = {}, trigger = {}, ready = true}
        pcall(function()
            if getconnections then
                for _, c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
                    if c.Function then table.insert(StealData[prompt].hold, c.Function) end
                end
                for _, c in ipairs(getconnections(prompt.Triggered)) do
                    if c.Function then table.insert(StealData[prompt].trigger, c.Function) end
                end
            end
        end)
    else
        if not prompt.Parent then StealData[prompt] = nil; return end
    end

    local data = StealData[prompt]
    if not data or not data.ready then return end
    data.ready = false; isStealing = true; stealStartTime = tick()

    if progressConnection then progressConnection:Disconnect(); progressConnection = nil end
    progressConnection = RunService.Heartbeat:Connect(function()
        if not isStealing then
            if progressConnection then progressConnection:Disconnect(); progressConnection = nil end
            return
        end
        local prog = math.clamp((tick() - stealStartTime) / STEAL_DURATION, 0, 1)
        if progressFill then progressFill.Size = UDim2.new(prog, 0, 1, 0) end
    end)

    task.spawn(function()
        for _, f in ipairs(data.hold) do pcall(f) end
        task.wait(STEAL_DURATION)
        if prompt and prompt.Parent then
            for _, f in ipairs(data.trigger) do pcall(f) end
        end
        if progressConnection then progressConnection:Disconnect(); progressConnection = nil end
        if progressFill then progressFill.Size = UDim2.new(0,0,1,0) end
        data.ready = true; isStealing = false; stealStartTime = nil
    end)
end

local function startAutoSteal()
    if autoStealConn then return end
    autoStealConn = RunService.Heartbeat:Connect(function()
        if not autoStealEnabled or isStealing then return end
        local p, _, n = findNearestPrompt()
        if p then executeSteal(p, n) end
    end)
end

local function stopAutoSteal()
    autoStealEnabled = false
    if autoStealConn then autoStealConn:Disconnect(); autoStealConn = nil end
    isStealing = false
    if progressConnection then progressConnection:Disconnect(); progressConnection = nil end
    StealData = {}
    resetBar(true)
end

-- =====================================================
-- SETUP CHARACTER
-- =====================================================
local function setupCharacter(char)
    character = char
    hrp = character:WaitForChild("HumanoidRootPart")
    hum = character:WaitForChild("Humanoid")

    if meleeEnabled then
        task.spawn(function() task.wait(0.3); createMeleeAimbot(char) end)
    end
    if batTeleportEnabled then
        task.spawn(function() task.wait(0.3); setupBatTeleport(char) end)
    end
    if noWalkEnabled then
        task.spawn(function()
            task.wait(0.5)
            local anim = char:FindFirstChild("Animate")
            if anim then savedAnimate = anim; anim.Disabled = true end
            local humN = char:FindFirstChildOfClass("Humanoid")
            if humN then for _, t in ipairs(humN:GetPlayingAnimationTracks()) do t:Stop() end end
        end)
    end
    if floatEnabled then
        task.delay(0.1, function()
            if floatEnabled then enableFloat() end
        end)
    end
end

if lp.Character then setupCharacter(lp.Character) end
lp.CharacterAdded:Connect(setupCharacter)

-- =====================================================
-- SPEED CUSTOMIZER GUI
-- =====================================================
local speedGui        = nil
local speedGuiActive  = false
local speedConnection = nil
local speedNoStealValue = 52
local speedStealValue   = 30
local jumpValue         = 50
local speedBox, stealBox, jumpBox

local function createSpeedCustomizerGui()
    if speedGui then return end
    pcall(function()
        local old = CoreGui:FindFirstChild("SpeedCustomizerGui_VH")
        if old then old:Destroy() end
    end)
    speedGui = Instance.new("ScreenGui")
    speedGui.Name = "SpeedCustomizerGui_VH"
    speedGui.ResetOnSpawn = false
    speedGui.Parent = CoreGui

    local FW = 215; local TH = 24; local BTH = 28; local RH = 25; local PAD = 6; local N = 3
    local savedPos  = uiPositions.speedCustomizer
    local panelOpen = (savedPos and savedPos.open ~= nil) and savedPos.open or false

    local function getHeight()
        if panelOpen then return TH + PAD + BTH + PAD + N * (RH + PAD) + PAD
        else return TH end
    end

    local vp    = workspace.CurrentCamera.ViewportSize
    local initX = savedPos and savedPos.x or (vp.X/2 - FW/2)
    local initY = savedPos and savedPos.y or (vp.Y * 0.15)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, FW, 0, getHeight())
    frame.Position = UDim2.new(0, initX, 0, initY)
    frame.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
    frame.BackgroundTransparency = 0.08
    frame.Active = true; frame.ClipsDescendants = true
    frame.Parent = speedGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local fs = Instance.new("UIStroke", frame)
    fs.Color = Color3.fromRGB(255, 185, 0); fs.Thickness = 1.5

    -- ── Title bar (like autowalk) ──────────────────
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, TH)
    titleBar.BackgroundColor3 = Color3.fromRGB(180, 120, 0)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0; titleBar.Parent = frame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 6)

    local arrowLbl = Instance.new("TextLabel")
    arrowLbl.Size = UDim2.new(0, 18, 1, 0)
    arrowLbl.Position = UDim2.new(0, 5, 0, 0)
    arrowLbl.BackgroundTransparency = 1
    arrowLbl.Font = Enum.Font.GothamBold; arrowLbl.TextSize = 10
    arrowLbl.TextColor3 = Color3.new(1, 1, 1)
    arrowLbl.Text = panelOpen and "-" or "+"
    arrowLbl.TextXAlignment = Enum.TextXAlignment.Left
    arrowLbl.Parent = titleBar

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -26, 1, 0)
    titleLbl.Position = UDim2.new(0, 22, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Font = Enum.Font.GothamBold; titleLbl.TextSize = 11
    titleLbl.TextColor3 = Color3.new(1, 1, 1)
    titleLbl.Text = "Custom Speed"
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = titleBar

    -- ── Content (hidden when collapsed) ───────────
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, 0, 1, -TH)
    contentFrame.Position = UDim2.new(0, 0, 0, TH)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Visible = panelOpen
    contentFrame.Parent = frame

    -- ON/OFF button inside content
    local onOffBtn = Instance.new("TextButton")
    onOffBtn.Size = UDim2.new(1, -10, 0, BTH)
    onOffBtn.Position = UDim2.new(0, 5, 0, PAD)
    onOffBtn.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
    onOffBtn.TextColor3 = Color3.new(1, 1, 1)
    onOffBtn.Font = Enum.Font.GothamBold; onOffBtn.TextSize = 12
    onOffBtn.Text = ""; onOffBtn.Parent = contentFrame
    Instance.new("UICorner", onOffBtn).CornerRadius = UDim.new(0, 6)
    local speedBtnStroke = Instance.new("UIStroke", onOffBtn)
    speedBtnStroke.Color = Color3.fromRGB(255, 185, 0); speedBtnStroke.Thickness = 1.5

    local rowsContainer = Instance.new("Frame")
    rowsContainer.Size = UDim2.new(1, 0, 0, N * (RH + PAD))
    rowsContainer.Position = UDim2.new(0, 0, 0, PAD + BTH + PAD)
    rowsContainer.BackgroundTransparency = 1
    rowsContainer.Parent = contentFrame

    local function makeRow(labelText, rowIndex, default)
        local posY = (rowIndex - 1) * (RH + PAD)
        local rowBg = Instance.new("Frame")
        rowBg.Size = UDim2.new(1, -10, 0, RH)
        rowBg.Position = UDim2.new(0, 5, 0, posY)
        rowBg.BackgroundColor3 = Color3.fromRGB(14, 18, 30)
        rowBg.BackgroundTransparency = 0.1; rowBg.Parent = rowsContainer
        Instance.new("UICorner", rowBg).CornerRadius = UDim.new(0, 6)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.55, 0, 1, 0)
        lbl.Position = UDim2.new(0, 8, 0, 0)
        lbl.BackgroundTransparency = 1; lbl.Text = labelText
        lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12
        lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = rowBg
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0.4, 0, 0, RH - 6)
        box.Position = UDim2.new(0.55, 2, 0.5, -(RH-6)/2)
        box.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
        box.TextColor3 = Color3.fromRGB(255, 255, 255)
        box.Text = tostring(default); box.Font = Enum.Font.GothamBold; box.TextSize = 12
        box.ClearTextOnFocus = false; box.Parent = rowBg
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
        local boxStroke = Instance.new("UIStroke", box)
        boxStroke.Color = Color3.fromRGB(180, 120, 0); boxStroke.Thickness = 1
        return box
    end

    speedBox = makeRow("Speed",       1, speedNoStealValue)
    stealBox = makeRow("Steal Speed", 2, speedStealValue)
    jumpBox  = makeRow("Jump",        3, jumpValue)

    local function applyInput(box, mn, mx, def)
        box.FocusLost:Connect(function()
            local num = math.clamp(tonumber(box.Text:gsub("%D","")) or def, mn, mx)
            box.Text = tostring(num)
            speedNoStealValue = tonumber(speedBox.Text) or speedNoStealValue
            speedStealValue   = tonumber(stealBox.Text) or speedStealValue
            pcall(mainSaveConfig)
        end)
    end
    applyInput(speedBox, 15, 200, 53)
    applyInput(stealBox, 15, 200, 29)
    applyInput(jumpBox,  50, 200, 60)

    local function saveSpeedPos()
        local ap = frame.AbsolutePosition
        uiPositions.speedCustomizer = {x = ap.X, y = ap.Y, open = panelOpen}
        pcall(saveUIPositions)
    end

    local function refreshOnOff()
        local state = speedGuiActive and "ON" or "OFF"
        onOffBtn.Text = "Custom Speed  —  " .. state
        if speedGuiActive then
            speedBtnStroke.Color = Color3.fromRGB(255, 185, 0)
            onOffBtn.TextColor3 = Color3.new(1, 1, 1)
        else
            speedBtnStroke.Color = Color3.fromRGB(40, 50, 70)
            onOffBtn.TextColor3 = Color3.fromRGB(120, 130, 150)
        end
    end

    local function updatePanel()
        arrowLbl.Text = panelOpen and "-" or "+"
        contentFrame.Visible = panelOpen
        frame.Size = UDim2.new(0, FW, 0, getHeight())
        speedGui.DisplayOrder = panelOpen and 10 or 1
        saveSpeedPos()
    end

    speedGui.DisplayOrder = panelOpen and 10 or 1

    titleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            panelOpen = not panelOpen; updatePanel()
        end
    end)

    onOffBtn.MouseButton1Click:Connect(function()
        speedGuiActive = not speedGuiActive
        if speedGuiActive then
            if speedConnection then speedConnection:Disconnect(); speedConnection = nil end
            speedConnection = RunService.Stepped:Connect(function()
                if character and hrp and hum then
                    speedNoStealValue = tonumber(speedBox.Text) or 53
                    speedStealValue   = tonumber(stealBox.Text) or 29
                    jumpValue         = tonumber(jumpBox.Text)  or 60
                    local md = hum.MoveDirection
                    if md.Magnitude > 0 then
                        local spd = (hum.WalkSpeed < 25) and speedStealValue or speedNoStealValue
                        local velY = floatDescending and -FLOAT_SPEED or hrp.Velocity.Y
                        hrp.Velocity = Vector3.new(md.X * spd, velY, md.Z * spd)
                    end
                end
            end)
        else
            if speedConnection then speedConnection:Disconnect(); speedConnection = nil end
        end
        refreshOnOff()
    end)

    speedGuiActive = true
    if speedConnection then speedConnection:Disconnect(); speedConnection = nil end
    speedConnection = RunService.Stepped:Connect(function()
        if character and hrp and hum then
            speedNoStealValue = tonumber(speedBox.Text) or 53
            speedStealValue   = tonumber(stealBox.Text) or 29
            jumpValue         = tonumber(jumpBox.Text)  or 60
            local md = hum.MoveDirection
            if md.Magnitude > 0 then
                local spd = (hum.WalkSpeed < 25) and speedStealValue or speedNoStealValue
                local velY = floatDescending and -FLOAT_SPEED or hrp.Velocity.Y
                hrp.Velocity = Vector3.new(md.X * spd, velY, md.Z * spd)
            end
        end
    end)

    speedBox.Text = tostring(speedNoStealValue)
    stealBox.Text = tostring(speedStealValue)
    jumpBox.Text  = tostring(jumpValue)
    refreshOnOff()

    local lastDragSave = 0
    makeDraggable(frame, function(_ap)
        task.defer(saveSpeedPos)
    end)
end

local function destroySpeedCustomizerGui()
    if speedGui then
        local frame = speedGui:FindFirstChildWhichIsA("Frame")
        if frame then
            local ap = frame.AbsolutePosition
            local existingOpen = uiPositions.speedCustomizer and uiPositions.speedCustomizer.open
            uiPositions.speedCustomizer = {x = ap.X, y = ap.Y, open = existingOpen ~= nil and existingOpen or true}
            pcall(saveUIPositions)
        end
        speedGui:Destroy(); speedGui = nil
    end
    speedGuiActive = false
    if speedConnection then speedConnection:Disconnect(); speedConnection = nil end
end

UserInputService.JumpRequest:Connect(function()
    if not character or not hum or not hrp then return end
    local st = hum:GetState()
    if speedGuiActive then
        if st == Enum.HumanoidStateType.Running or st == Enum.HumanoidStateType.Landed then
            local jp = tonumber(jumpBox and jumpBox.Text) or 70
            hrp.AssemblyLinearVelocity = Vector3.new(
                hrp.AssemblyLinearVelocity.X, jp, hrp.AssemblyLinearVelocity.Z)
        end
    end
    if infiniteJumpEnabled then
        hrp.AssemblyLinearVelocity = Vector3.new(
            hrp.AssemblyLinearVelocity.X, 50, hrp.AssemblyLinearVelocity.Z)
    end
end)

-- =====================================================
-- AUTO WALK, BAT TELEPORT & LOCK
-- =====================================================
-- [Skipped auto walk gui rebuild definition to save space, retaining base logic if needed]
local lockEnabled = false
local lockGui; local lockHbConn; local lockLv; local lockAtt; local lockGyro
LOCK_RADIUS = 100; local LOCK_SPEED = 52

local function getNearest()
    local char = lp.Character; if not char then return nil end
    local hrpN = char:FindFirstChild("HumanoidRootPart"); if not hrpN then return nil end
    local nearest; local nearestDist = LOCK_RADIUS
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp then
            local pc = plr.Character
            local phrp = pc and pc:FindFirstChild("HumanoidRootPart")
            if phrp then
                local d = (phrp.Position - hrpN.Position).Magnitude
                if d <= nearestDist then nearest = plr; nearestDist = d end
            end
        end
    end
    return nearest
end

local function startLock()
    local char = lp.Character; if not char then return end
    local hrpL = char:FindFirstChild("HumanoidRootPart"); if not hrpL then return end
    lockAtt = Instance.new("Attachment", hrpL)
    lockLv = Instance.new("LinearVelocity", hrpL); lockLv.Attachment0 = lockAtt
    lockLv.MaxForce = 50000; lockLv.RelativeTo = Enum.ActuatorRelativeTo.World
    lockLv.Enabled = false
    lockGyro = Instance.new("AlignOrientation", hrpL); lockGyro.Attachment0 = lockAtt
    lockGyro.MaxTorque = 50000; lockGyro.Responsiveness = 120; lockGyro.Enabled = false
    lockHbConn = RunService.Heartbeat:Connect(function()
        local targetPlayer = getNearest()
        if not targetPlayer then
            lockLv.Enabled = false; lockGyro.Enabled = false; return
        end
        local tChar = targetPlayer.Character
        local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if not tHrp then lockLv.Enabled = false; lockGyro.Enabled = false; return end
        lockLv.Enabled = true; lockGyro.Enabled = true
        local tTorso = tChar:FindFirstChild("Torso") or tChar:FindFirstChild("UpperTorso")
        local torsoPos = tTorso and tTorso.Position or tHrp.Position
        local backPos = torsoPos - tHrp.CFrame.LookVector * 0.5
        local dir = backPos - hrpL.Position
        if dir.Magnitude > 0.3 then lockLv.VectorVelocity = dir.Unit * LOCK_SPEED
        else lockLv.VectorVelocity = Vector3.zero end
        lockGyro.CFrame = CFrame.lookAt(hrpL.Position, backPos)
    end)
end

local function stopLock()
    if lockHbConn then lockHbConn:Disconnect(); lockHbConn = nil end
    if lockLv then lockLv:Destroy(); lockLv = nil end
    if lockGyro then lockGyro:Destroy(); lockGyro = nil end
    if lockAtt then lockAtt:Destroy(); lockAtt = nil end
end

function createLockGui()
    if lockGui then return end
    lockGui = Instance.new("ScreenGui"); lockGui.Name = "VincitoreBatTarget"
    lockGui.ResetOnSpawn = false; lockGui.Parent = CoreGui
    local vp = workspace.CurrentCamera.ViewportSize
    local lkX = uiPositions.lockGui and uiPositions.lockGui.x or (vp.X/2 - 71)
    local lkY = uiPositions.lockGui and uiPositions.lockGui.y or (vp.Y * 0.75)

    -- Outer frame carries the gold outline
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 142, 0, 47)
    frame.Position = UDim2.new(0, lkX, 0, lkY)
    frame.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
    frame.BackgroundTransparency = 0.08
    frame.Active = true
    frame.Parent = lockGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local lockFrameStroke = Instance.new("UIStroke", frame)
    lockFrameStroke.Color = Color3.fromRGB(255, 185, 0); lockFrameStroke.Thickness = 1.5

    -- Button fills the frame, no stroke
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = "LOCK"; btn.Font = Enum.Font.GothamBold; btn.TextSize = 16
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Parent = frame

    btn.MouseButton1Click:Connect(function()
        lockEnabled = not lockEnabled
        if lockEnabled then
            btn.Text = "LOCKED"
            frame.BackgroundColor3 = Color3.fromRGB(140, 0, 0)
            lockFrameStroke.Color = Color3.fromRGB(200, 0, 0); startLock()
        else
            btn.Text = "LOCK"
            frame.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
            lockFrameStroke.Color = Color3.fromRGB(255, 185, 0); stopLock()
        end
    end)

    makeDraggable(frame, function(ap)
        uiPositions.lockGui = {x = ap.X, y = ap.Y}
        pcall(saveUIPositions)
    end, btn)
end

function destroyLockGui()
    lockEnabled = false; stopLock()
    if lockGui then
        local frame = lockGui:FindFirstChildWhichIsA("Frame")
        if frame then
            local ap = frame.AbsolutePosition
            uiPositions.lockGui = {x = ap.X, y = ap.Y}
            pcall(saveUIPositions)
        end
        lockGui:Destroy(); lockGui = nil
    end
end

-- =====================================================
-- FLOAT  (@rznnq v3 — exact logic, integrated)
-- =====================================================
local floatEnabled    = false
local floatGui        = nil
local floatPlatform   = nil   -- maps to "platform" in source
local floatConn       = nil   -- maps to "floatConn"
local floatSinkConn   = nil   -- maps to "sinkConn"
local floatIsToggling = false
local floatDescending = false  -- true saat descent aktif

local FLOAT_HEIGHT = 1    -- studs
local FLOAT_SPEED  = 500  -- studs/sec for BOTH rise AND descent

local function getFloatHRP()
    local c = lp.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function stopFloatConn()
    if floatConn then floatConn:Disconnect(); floatConn = nil end
end
local function stopFloatSink()
    if floatSinkConn then floatSinkConn:Disconnect(); floatSinkConn = nil end
end
local function destroyFloatPlatform()
    if floatPlatform and floatPlatform.Parent then floatPlatform:Destroy() end
    floatPlatform = nil
end

local function enableFloat()
    stopFloatConn()
    destroyFloatPlatform()
    local root = getFloatHRP(); if not root then return end

    local startY  = root.Position.Y - 3
    local targetY = startY + FLOAT_HEIGHT

    local p = Instance.new("Part")
    p.Size       = Vector3.new(6, 1, 6)
    p.Anchored   = true
    p.CanCollide = false
    p.Transparency = 1
    p.CastShadow = false
    p.Position   = Vector3.new(root.Position.X, startY, root.Position.Z)
    p.Parent     = workspace
    floatPlatform = p

    local rising = true
    floatConn = RunService.Heartbeat:Connect(function(dt)
        if not (p and p.Parent) then stopFloatConn(); return end
        local r = getFloatHRP(); if not r then return end

        if rising then
            local prevY  = p.Position.Y
            local newY   = math.min(prevY + FLOAT_SPEED * dt, targetY)
            local deltaY = newY - prevY
            p.Position = Vector3.new(r.Position.X, newY, r.Position.Z)
            r.CFrame   = r.CFrame + Vector3.new(0, deltaY, 0)
            if newY >= targetY then
                p.CanCollide = true
                rising = false
            end
        else
            p.Position = Vector3.new(r.Position.X, targetY, r.Position.Z)
        end
    end)
end

local function disableFloat()
    floatEnabled = false
    stopFloatConn()
    stopFloatSink()

    local sinkTarget = floatPlatform
    floatPlatform = nil
    if not (sinkTarget and sinkTarget.Parent) then return end

    local root = getFloatHRP()
    if not root then sinkTarget:Destroy(); return end

    local char = lp.Character
    local humD = char and char:FindFirstChildOfClass("Humanoid")

    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = { char, sinkTarget }
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local hit       = workspace:Raycast(root.Position, Vector3.new(0, -500, 0), rayParams)
    local landY     = hit and (hit.Position.Y + 3) or (root.Position.Y - FLOAT_HEIGHT)
    local platLandY = landY - 3

    sinkTarget.CanCollide = false
    floatDescending = true

    -- PlatformStand = true: matikan Humanoid physics control sepenuhnya
    -- Ini yang membuat standalone bekerja — di sana tidak ada Humanoid state machine aktif
    if humD then humD.PlatformStand = true end

    floatSinkConn = RunService.Heartbeat:Connect(function(dt)
        local r = getFloatHRP()
        if not (sinkTarget and sinkTarget.Parent) or not r then
            floatDescending = false
            if humD then humD.PlatformStand = false end
            stopFloatSink(); return
        end
        local prevY  = sinkTarget.Position.Y
        local newY   = math.max(prevY - FLOAT_SPEED * dt, platLandY)
        local deltaY = newY - prevY
        sinkTarget.Position = Vector3.new(r.Position.X, newY, r.Position.Z)
        r.CFrame = r.CFrame + Vector3.new(0, deltaY, 0)
        if newY <= platLandY then
            floatDescending = false
            if humD then humD.PlatformStand = false end
            sinkTarget:Destroy()
            stopFloatSink()
        end
    end)
end

function createFloatGui()
    if floatGui then return end
    floatGui = Instance.new("ScreenGui"); floatGui.Name = "VincitoreFloatGui"
    floatGui.ResetOnSpawn = false; floatGui.Parent = CoreGui
    local vp = workspace.CurrentCamera.ViewportSize
    local fx = uiPositions.floatGui and uiPositions.floatGui.x or (vp.X/2 + 80)
    local fy = uiPositions.floatGui and uiPositions.floatGui.y or (vp.Y * 0.75)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 142, 0, 47)
    frame.Position = UDim2.new(0, fx, 0, fy)
    frame.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
    frame.BackgroundTransparency = 0.08
    frame.Active = true; frame.Parent = floatGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local floatStroke = Instance.new("UIStroke", frame)
    floatStroke.Color = Color3.fromRGB(255, 185, 0); floatStroke.Thickness = 1.5

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0); btn.BackgroundTransparency = 1
    btn.Text = "FLOAT"; btn.Font = Enum.Font.GothamBold; btn.TextSize = 16
    btn.TextColor3 = Color3.new(1, 1, 1); btn.Parent = frame

    local function setVisual(on)
        if on then
            btn.Text = "FLOATING"
            TweenService:Create(frame, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(50, 20, 120)}):Play()
            floatStroke.Color = Color3.fromRGB(160, 100, 255)
        else
            btn.Text = "FLOAT"
            TweenService:Create(frame, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(10, 12, 20)}):Play()
            floatStroke.Color = Color3.fromRGB(255, 185, 0)
        end
    end

    btn.MouseButton1Click:Connect(function()
        if floatIsToggling then return end
        floatIsToggling = true
        floatEnabled = not floatEnabled
        if floatEnabled then enableFloat() else disableFloat() end
        setVisual(floatEnabled)
        task.delay(0.05, function() floatIsToggling = false end)
    end)

    makeDraggable(frame, function(ap)
        uiPositions.floatGui = {x = ap.X, y = ap.Y}
        pcall(saveUIPositions)
    end, btn)
end

function destroyFloatGui()
    floatEnabled = false
    stopFloatConn(); stopFloatSink(); destroyFloatPlatform()
    if floatGui then
        local frame = floatGui:FindFirstChildWhichIsA("Frame")
        if frame then
            local ap = frame.AbsolutePosition
            uiPositions.floatGui = {x = ap.X, y = ap.Y}
            pcall(saveUIPositions)
        end
        floatGui:Destroy(); floatGui = nil
    end
end

-- ── Medusa ────────────────────────────────────────
MEDUSA_RADIUS = 10
local SPAM_DELAY       = 0.15
local medusaPart
local lastMedusaUse    = 0
local AutoMedusaEnabled = false
local MedusaInitialized = false

local function InitMedusa()
    if MedusaInitialized then return end
    MedusaInitialized = true
    local function createRadius()
        if medusaPart then medusaPart:Destroy() end
        medusaPart = Instance.new("Part"); medusaPart.Name = "MedusaRadius"
        medusaPart.Anchored = true; medusaPart.CanCollide = false
        medusaPart.Transparency = 1; medusaPart.Material = Enum.Material.Neon
        medusaPart.Color = Color3.fromRGB(255,0,0); medusaPart.Shape = Enum.PartType.Cylinder
        medusaPart.Size = Vector3.new(0.05, MEDUSA_RADIUS*2, MEDUSA_RADIUS*2)
        medusaPart.Parent = workspace
    end
    local function isMedusaEquipped()
        local char = lp.Character; if not char then return nil end
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == "Medusa's Head" then return tool end
        end
        return nil
    end
    createRadius()
    RunService.RenderStepped:Connect(function()
        if not AutoMedusaEnabled then
            if medusaPart then medusaPart.Transparency = 1 end; return
        end
        medusaPart.Transparency = 0.1
        local char = lp.Character; if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
        medusaPart.CFrame = CFrame.new(root.Position + Vector3.new(0,-2.5,0))
            * CFrame.Angles(0,0,math.rad(90))
    end)
    RunService.Heartbeat:Connect(function()
        if not AutoMedusaEnabled then return end
        local char = lp.Character; if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
        local tool = isMedusaEquipped(); if not tool then return end
        if tick() - lastMedusaUse < SPAM_DELAY then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lp then
                local pChar = plr.Character
                local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
                if pRoot and (pRoot.Position - root.Position).Magnitude <= MEDUSA_RADIUS then
                    tool:Activate(); lastMedusaUse = tick(); break
                end
            end
        end
    end)
end

task.wait(1)

-- =====================================================
-- MAIN SCREEN GUI
-- =====================================================
local sg = Instance.new("ScreenGui")
sg.Name = "VincitoreDuels"
sg.ResetOnSpawn = false
sg.Parent = CoreGui
RunService.Heartbeat:Connect(function()
    if not sg or not sg.Parent then sg.Parent = CoreGui end
end)

-- ── (Auto Steal progress bar is embedded in the top bar below) ──

-- ── Top Bar (FPS + Ping) ──────────────────────────
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(0, 260, 0, 30)
topBar.Position = UDim2.new(0.5, -130, 0, 15)
topBar.BackgroundColor3 = Color3.fromRGB(12, 16, 28)
topBar.Parent = sg
Instance.new("UICorner", topBar).CornerRadius = UDim.new(1, 0)
local strokeTop = Instance.new("UIStroke", topBar)
strokeTop.Color = Color3.fromRGB(255, 185, 0); strokeTop.Thickness = 1.5

local topLabel = Instance.new("TextLabel")
topLabel.Size = UDim2.new(1, 0, 1, 0)
topLabel.BackgroundTransparency = 1
topLabel.Font = Enum.Font.GothamBold; topLabel.TextSize = 13
topLabel.TextColor3 = Color3.new(1, 1, 1)
topLabel.Parent = topBar

local fps, framesCount, lastTick = 60, 0, tick()
RunService.RenderStepped:Connect(function()
    framesCount += 1
    if tick() - lastTick >= 1 then fps = framesCount; framesCount = 0; lastTick = tick() end
    local ping = 0
    local network = Stats:FindFirstChild("Network")
    if network and network:FindFirstChild("ServerStatsItem") then
        local dp = network.ServerStatsItem:FindFirstChild("Data Ping")
        if dp then ping = math.floor(dp:GetValue()) end
    end
    topLabel.Text = "Vincitore Duels | " .. fps .. " FPS | " .. ping .. " ms"
end)

-- ── Auto Steal Progress Bar (thin line at bottom of top bar) ──
progressBarBg = Instance.new("Frame")
progressBarBg.Name = "StealBarBg"
progressBarBg.Size = UDim2.new(1, -8, 0, 3)
progressBarBg.Position = UDim2.new(0, 4, 1, -5)
progressBarBg.BackgroundColor3 = Color3.fromRGB(30, 35, 55)
progressBarBg.BorderSizePixel = 0
progressBarBg.ClipsDescendants = true
progressBarBg.Parent = topBar
Instance.new("UICorner", progressBarBg).CornerRadius = UDim.new(1, 0)

progressFill = Instance.new("Frame")
progressFill.Name = "StealBarFill"
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(255, 185, 0)
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBarBg
Instance.new("UICorner", progressFill).CornerRadius = UDim.new(1, 0)

-- ── Toggle Button (Menu) ──────────────────────────
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 75, 0, 35)
toggleBtn.Position = UDim2.new(0, 15, 0.5, -17)
toggleBtn.BackgroundColor3 = Color3.fromRGB(12, 16, 28)
toggleBtn.Text = "Menu"
toggleBtn.Font = Enum.Font.GothamBold; toggleBtn.TextSize = 14
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Parent = sg
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0.5, 0)
local menuStroke = Instance.new("UIStroke", toggleBtn)
menuStroke.Color = Color3.fromRGB(255, 185, 0); menuStroke.Thickness = 1.5

-- ── Hub Panel (Moon Hub Style) ─────────────────────
local HUB_WIDTH = 450; local HUB_HEIGHT = 280
local hub = Instance.new("Frame")
hub.Size = UDim2.new(0, HUB_WIDTH, 0, HUB_HEIGHT)
hub.Position = UDim2.new(0, -HUB_WIDTH - 50, 0.5, -HUB_HEIGHT / 2)
hub.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
hub.BorderSizePixel = 0
hub.Parent = sg
Instance.new("UICorner", hub).CornerRadius = UDim.new(0, 8)
local strokeHub = Instance.new("UIStroke", hub)
strokeHub.Color = Color3.fromRGB(180, 120, 0); strokeHub.Thickness = 1.5

-- Sidebar background
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 120, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(14, 18, 30)
sidebar.BorderSizePixel = 0
sidebar.Parent = hub
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 8)

local hideCorners = Instance.new("Frame")
hideCorners.Size = UDim2.new(0, 10, 1, 0)
hideCorners.Position = UDim2.new(1, -10, 0, 0)
hideCorners.BackgroundColor3 = Color3.fromRGB(14, 18, 30)
hideCorners.BorderSizePixel = 0
hideCorners.Parent = sidebar

local hubTitle = Instance.new("TextLabel")
hubTitle.Size = UDim2.new(1, 0, 0, 50)
hubTitle.BackgroundTransparency = 1
hubTitle.Font = Enum.Font.GothamBlack; hubTitle.TextSize = 14
hubTitle.TextColor3 = Color3.fromRGB(255, 185, 0)
hubTitle.Text = "VINCITORE"
hubTitle.Parent = sidebar


-- =====================================================
-- SECTIONS + SECTION BUTTONS
-- =====================================================
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -130, 1, -20)
content.Position = UDim2.new(0, 130, 0, 10)
content.BackgroundTransparency = 1
content.Parent = hub

local sections = {"Duels", "Player", "Visual", "Settings"}
local sectionButtons = {}
local frames = {}

for _, name in ipairs(sections) do
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, 0); scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness = 4; scroll.BackgroundTransparency = 1
    scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 185, 0)
    scroll.Visible = false; scroll.Name = name .. "Frame"; scroll.Parent = content
    local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 6)
    layout.Parent = scroll
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end)
    frames[name] = scroll
end

local function ShowSection(sectionName)
    for _, f in pairs(frames) do f.Visible = false end
    frames[sectionName].Visible = true
    for _, b in pairs(sectionButtons) do 
        b.BackgroundColor3 = Color3.fromRGB(14, 18, 30)
        b.TextColor3 = Color3.fromRGB(150, 150, 150)
    end
    for _, b in pairs(sectionButtons) do
        if b.Text == sectionName then 
            b.BackgroundColor3 = Color3.fromRGB(255, 185, 0) 
            b.TextColor3 = Color3.new(1, 1, 1)
        end
    end
end

for i, v in ipairs(sections) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -16, 0, 30)
    btn.Position = UDim2.new(0, 8, 0, 50 + (i - 1) * 36)
    btn.BackgroundColor3 = Color3.fromRGB(14, 18, 30)
    btn.Text = v
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 13
    btn.TextColor3 = Color3.fromRGB(150, 150, 150)
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    table.insert(sectionButtons, btn)
    btn.MouseButton1Click:Connect(function() ShowSection(v) end)
end

-- =====================================================
-- TOGGLE SYSTEM
-- =====================================================
local toggleSetters = {}
local toggleStates  = {}
local MAIN_CFG_FILE = "VincitoreDuels_Config.json"

function mainSaveConfig()
    pcall(function()
        local data = {
            toggles        = toggleStates,
            LOCK_RADIUS    = LOCK_RADIUS,
            MEDUSA_RADIUS  = MEDUSA_RADIUS,
            MELEE_RANGE    = MELEE_RANGE,
            grabRadius     = grabRadius,
            STEAL_DURATION = STEAL_DURATION,
            speedNoSteal   = speedNoStealValue,
            speedSteal     = speedStealValue,
            batSide        = batSelectedSide,
        }
        writefile(MAIN_CFG_FILE, HttpService:JSONEncode(data))
    end)
end

function mainLoadConfig()
    pcall(function()
        local ok, raw = pcall(readfile, MAIN_CFG_FILE)
        if not ok or not raw or raw == "" then return end
        local data = HttpService:JSONDecode(raw)
        if data.LOCK_RADIUS    then LOCK_RADIUS        = data.LOCK_RADIUS   end
        if data.MEDUSA_RADIUS  then MEDUSA_RADIUS      = data.MEDUSA_RADIUS end
        if data.MELEE_RANGE    then MELEE_RANGE        = data.MELEE_RANGE   end
        if data.grabRadius     then grabRadius         = data.grabRadius
                                     STEAL_RADIUS      = data.grabRadius     end
        if data.STEAL_DURATION then STEAL_DURATION     = data.STEAL_DURATION end
        if data.speedNoSteal   then speedNoStealValue  = data.speedNoSteal  end
        if data.speedSteal     then speedStealValue    = data.speedSteal    end
        if data.batSide        then batSelectedSide    = data.batSide       end
        if data.toggles then
            for name, state in pairs(data.toggles) do
                if toggleSetters[name] and state then toggleSetters[name](true) end
            end
        end
    end)
end

local autoBatActive = false; local autoBatLoop = nil

-- =====================================================
-- SHARED AUTOWALK STATE  (diakses oleh TP post-walk)
-- =====================================================
local awShared = {
    editA = nil,  -- referensi ke editPointsA di dalam createAutoWalkGui
    editB = nil,  -- referensi ke editPointsB
    dir   = "right",
}
local awPostTpDelay   = 0.055
local awPostTpConn    = nil
local awPostTpRunning = false
local awPostTpOnEnd   = nil

local function cancelPostTpWalk()
    awPostTpRunning = false
    if awPostTpConn then awPostTpConn:Disconnect(); awPostTpConn = nil end
    if awPostTpOnEnd then awPostTpOnEnd() end
    if _batOnWalkEnd then _batOnWalkEnd() end
end

-- dipanggil dari doManualTP setelah teleport selesai
local function startPostTpWalk(side)
    cancelPostTpWalk()
    -- side "B"=RIGHT → editA (rawSetA = right waypoints)
    -- side "A"=LEFT  → editB (rawSetB = left waypoints)
    local pts = (side == "B") and awShared.editA or awShared.editB
    if not pts or #pts < 3 then return end

    -- waypoints = P3, P4, P5
    local wps = {}
    for i = 3, #pts do
        table.insert(wps, pts[i])
    end
    if #wps == 0 then return end

    awPostTpRunning = true
    task.spawn(function()
        -- tunggu delay sebelum mulai jalan
        task.wait(awPostTpDelay)
        if not awPostTpRunning then return end

        local currentWp = 1
        awPostTpConn = RunService.Stepped:Connect(function()
            if not awPostTpRunning then cancelPostTpWalk(); return end
            local char = lp.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then cancelPostTpWalk(); return end

            local wp = wps[currentWp]
            if not wp then cancelPostTpWalk(); return end

            -- XZ-only distance (kompatibel dengan float)
            local distXZ = (Vector3.new(root.Position.X, 0, root.Position.Z)
                          - Vector3.new(wp.x, 0, wp.z)).Magnitude
            if distXZ < 5 then
                if currentWp == #wps then
                    cancelPostTpWalk(); return
                end
                currentWp += 1
            else
                -- XZ-only direction
                local flatTarget = Vector3.new(wp.x, root.Position.Y, wp.z)
                local dir = (flatTarget - root.Position).Unit
                root.Velocity = Vector3.new(dir.X * wp.speed, root.Velocity.Y, dir.Z * wp.speed)
            end
        end)
    end)
end
_batStartWalk = startPostTpWalk   -- forward-ref resolved

-- =====================================================
-- AUTO WALK GUI
-- =====================================================
local function createAutoWalkGui()
    if walkGui then return end
    pcall(function()
        local old = CoreGui:FindFirstChild("WalkButtonGui")
        if old then old:Destroy() end
    end)
    walkGui = Instance.new("ScreenGui"); walkGui.Name = "WalkButtonGui"
    walkGui.ResetOnSpawn = false; walkGui.Parent = CoreGui
    local rawSetA = {
        {x=-474,y=-7,z=23,speed=58},{x=-474,y=-7,z=58,speed=58},
        {x=-474,y=-7,z=90,speed=56},{x=-474,y=-7,z=112,speed=30},
        {x=-474,y=-7,z=130,speed=30},
    }
    local rawSetB = {
        {x=-475,y=-7,z=96,speed=58},{x=-474,y=-7,z=63,speed=58},
        {x=-474,y=-7,z=33,speed=56},{x=-473,y=-7,z=11,speed=30},
        {x=-473,y=-7,z=-10,speed=30},
    }
    local editPointsA = {}; local editPointsB = {}
    for i,r in ipairs(rawSetA) do editPointsA[i]={x=r.x,y=r.y,z=r.z,speed=r.speed} end
    for i,r in ipairs(rawSetB) do editPointsB[i]={x=r.x,y=r.y,z=r.z,speed=r.speed} end
    -- expose ke post-TP walk (referensi tabel, bukan copy)
    awShared.editA = editPointsA
    awShared.editB = editPointsB
    local selectedDir = "right"; local activeEdit = editPointsA
    local CFG_FILE = "VH_AutoWalk.json"; local savedDelay = 0.3
    local function saveWalkConfig()
        pcall(function()
            local data = {delay=savedDelay, setA={}, setB={}, dir=selectedDir}
            for i,ep in ipairs(editPointsA) do data.setA[i]={x=ep.x,y=ep.y,z=ep.z,speed=ep.speed} end
            for i,ep in ipairs(editPointsB) do data.setB[i]={x=ep.x,y=ep.y,z=ep.z,speed=ep.speed} end
            writefile(CFG_FILE, HttpService:JSONEncode(data))
        end)
    end
    local function loadWalkConfig()
        pcall(function()
            local ok, raw = pcall(readfile, CFG_FILE)
            if not ok or not raw or raw == "" then return end
            local data = HttpService:JSONDecode(raw)
            if data.delay then savedDelay = data.delay end
            if data.dir   then selectedDir = data.dir end
            if data.setA then
                for i,ep in ipairs(data.setA) do
                    if editPointsA[i] then
                        editPointsA[i].x=ep.x or editPointsA[i].x
                        editPointsA[i].z=ep.z or editPointsA[i].z
                        editPointsA[i].speed=ep.speed or editPointsA[i].speed
                    end
                end
            end
            if data.setB then
                for i,ep in ipairs(data.setB) do
                    if editPointsB[i] then
                        editPointsB[i].x=ep.x or editPointsB[i].x
                        editPointsB[i].z=ep.z or editPointsB[i].z
                        editPointsB[i].speed=ep.speed or editPointsB[i].speed
                    end
                end
            end
        end)
    end
    loadWalkConfig(); activeEdit = (selectedDir=="right") and editPointsA or editPointsB
    awShared.dir = selectedDir  -- sync initial dir
    local colorsRight = {Color3.fromRGB(0,180,255),Color3.fromRGB(0,140,220),Color3.fromRGB(180,120,0),Color3.fromRGB(0,50,160),Color3.fromRGB(0,20,120)}
    local colorsLeft  = {Color3.fromRGB(255,140,0),Color3.fromRGB(230,110,0),Color3.fromRGB(200,80,0),Color3.fromRGB(160,40,0),Color3.fromRGB(120,10,0)}
    local function getMarkerColors() return (selectedDir=="right") and colorsRight or colorsLeft end
    local markerFolder = Instance.new("Folder"); markerFolder.Name="AutoWalkMarkers_VH"; markerFolder.Parent=workspace
    local markers3D = {}
    local function destroyMarkers()
        for _,c in ipairs(markerFolder:GetChildren()) do c:Destroy() end; markers3D={}
    end
    local function buildMarkers(pts)
        destroyMarkers(); local cols=getMarkerColors(); local dl=(selectedDir=="right") and "R" or "L"
        for i,ep in ipairs(pts) do
            local col=cols[i] or Color3.fromRGB(255,255,255)
            local sphere=Instance.new("Part"); sphere.Shape=Enum.PartType.Block
            sphere.Size=Vector3.new(2,5,2)
            sphere.Position=Vector3.new(ep.x,ep.y-1,ep.z)
            sphere.Anchored=true; sphere.CanCollide=false; sphere.CastShadow=false
            sphere.Material=Enum.Material.Neon; sphere.Color=col; sphere.Transparency=0.15
            sphere.Parent=markerFolder
            local bb=Instance.new("BillboardGui"); bb.Size=UDim2.new(0,44,0,20)
            bb.StudsOffset=Vector3.new(0,3,0); bb.AlwaysOnTop=true; bb.Parent=sphere
            local bg=Instance.new("Frame"); bg.Size=UDim2.new(1,0,1,0)
            bg.BackgroundColor3=Color3.fromRGB(5,5,5); bg.BackgroundTransparency=0
            bg.BorderSizePixel=0; bg.Parent=bb
            Instance.new("UICorner",bg).CornerRadius=UDim.new(0,4)
            local bgS=Instance.new("UIStroke",bg); bgS.Color=col; bgS.Thickness=1.5
            local lbWalk=Instance.new("TextLabel"); lbWalk.Size=UDim2.new(1,0,1,0)
            lbWalk.BackgroundTransparency=1; lbWalk.Text=dl.."P"..i
            lbWalk.TextColor3=col; lbWalk.Font=Enum.Font.GothamBold
            lbWalk.TextSize=12; lbWalk.TextScaled=false; lbWalk.TextStrokeTransparency=1
            lbWalk.Parent=bg; markers3D[i]=sphere
        end
    end
    local function highlightMarker(idx)
        for j,m in ipairs(markers3D) do
            if m and m.Parent then
                m.Size=(j==idx) and Vector3.new(2,6,2) or Vector3.new(2,5,2)
                m.Transparency=(j==idx) and 0 or 0.15
            end
        end
    end
    local function resetMarkerSizes()
        for _,m in ipairs(markers3D) do
            if m and m.Parent then m.Size=Vector3.new(2,5,2); m.Transparency=0.15 end
        end
    end
    buildMarkers(activeEdit)
    local FW=205; local RH=26; local HH=24; local BH=26; local TBH=24
    local IW=44; local IH=18; local PAD=5; local N=5
    local _awPos = uiPositions.autoWalk
    local panelOpen = (_awPos and _awPos.open ~= nil) and _awPos.open or false
    local walkDelay=savedDelay
    local function getHeight()
        if panelOpen then return HH+PAD+BH+PAD+14+PAD+TBH+PAD+28+N*RH+PAD+RH+PAD+BH+PAD
        else return HH+PAD+BH+PAD+14+PAD end
    end
    local awX = uiPositions.autoWalk and uiPositions.autoWalk.x or nil
    local awY = uiPositions.autoWalk and uiPositions.autoWalk.y or nil
    local frame=Instance.new("Frame"); frame.Size=UDim2.new(0,FW,0,getHeight())
    if awX and awY then
        frame.Position=UDim2.new(0, awX, 0, awY)
    else
        local vp=workspace.CurrentCamera.ViewportSize
        frame.Position=UDim2.new(0, vp.X/2-FW/2, 0, vp.Y*0.55)
    end
    frame.BackgroundColor3=Color3.fromRGB(10,12,20)
    frame.BackgroundTransparency=0.08; frame.Active=true
    frame.ClipsDescendants=true; frame.Parent=walkGui
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,8)
    local fs=Instance.new("UIStroke",frame); fs.Color=Color3.fromRGB(255,185,0); fs.Thickness=1.5
    local _lastAwSave = 0
    local saveAutoWalkPos
    makeDraggable(frame, function(ap)
        uiPositions.autoWalk = {x = ap.X, y = ap.Y, open = panelOpen}
        pcall(saveUIPositions)
    end)
    local titleBar=Instance.new("Frame"); titleBar.Size=UDim2.new(1,0,0,HH)
    titleBar.BackgroundColor3=Color3.fromRGB(180,120,0); titleBar.BackgroundTransparency=0.2
    titleBar.BorderSizePixel=0; titleBar.Parent=frame
    Instance.new("UICorner",titleBar).CornerRadius=UDim.new(0,6)
    local arrowLbl=Instance.new("TextLabel"); arrowLbl.Size=UDim2.new(0,18,1,0)
    arrowLbl.Position=UDim2.new(0,5,0,0); arrowLbl.BackgroundTransparency=1
    arrowLbl.Font=Enum.Font.GothamBold; arrowLbl.TextSize=10; arrowLbl.TextColor3=Color3.new(1,1,1)
    arrowLbl.Text="-"; arrowLbl.TextXAlignment=Enum.TextXAlignment.Left; arrowLbl.Parent=titleBar
    local titleWalk=Instance.new("TextLabel"); titleWalk.Size=UDim2.new(1,-26,1,0)
    titleWalk.Position=UDim2.new(0,22,0,0); titleWalk.BackgroundTransparency=1
    titleWalk.Font=Enum.Font.GothamBold; titleWalk.TextSize=11; titleWalk.TextColor3=Color3.new(1,1,1)
    titleWalk.Text="Auto Walk"; titleWalk.TextXAlignment=Enum.TextXAlignment.Left
    titleWalk.Parent=titleBar
    local btnY=HH+PAD
    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,-10,0,BH)
    btn.Position=UDim2.new(0,5,0,btnY); btn.Text="PLAY"
    btn.Font=Enum.Font.GothamBold; btn.TextSize=12; btn.TextColor3=Color3.new(1,1,1)
    btn.BackgroundColor3=Color3.fromRGB(255,185,0); btn.Parent=frame
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
    local statusY=btnY+BH+PAD
    local statusLbl=Instance.new("TextLabel"); statusLbl.Size=UDim2.new(1,-10,0,14)
    statusLbl.Position=UDim2.new(0,5,0,statusY); statusLbl.BackgroundTransparency=1
    statusLbl.Font=Enum.Font.Gotham; statusLbl.TextSize=9
    statusLbl.TextColor3=Color3.fromRGB(150,150,150)
    statusLbl.Text="Press PLAY to begin"; statusLbl.TextXAlignment=Enum.TextXAlignment.Center
    statusLbl.Parent=frame
    local toggleBarY=statusY+14+PAD
    local toggleBarContainer=Instance.new("Frame"); toggleBarContainer.Size=UDim2.new(1,-10,0,TBH)
    toggleBarContainer.Position=UDim2.new(0,5,0,toggleBarY); toggleBarContainer.BackgroundTransparency=1
    toggleBarContainer.Parent=frame
    local halfW=math.floor((FW-10-4)/2)
    local btnRight=Instance.new("TextButton"); btnRight.Size=UDim2.new(0,halfW,1,0)
    btnRight.Position=UDim2.new(0,0,0,0); btnRight.Font=Enum.Font.GothamBold
    btnRight.TextSize=10; btnRight.TextColor3=Color3.new(1,1,1); btnRight.Text="AUTO RIGHT"
    btnRight.Parent=toggleBarContainer; Instance.new("UICorner",btnRight).CornerRadius=UDim.new(0,6)
    local btnLeft=Instance.new("TextButton"); btnLeft.Size=UDim2.new(0,halfW,1,0)
    btnLeft.Position=UDim2.new(0,halfW+4,0,0); btnLeft.Font=Enum.Font.GothamBold
    btnLeft.TextSize=10; btnLeft.TextColor3=Color3.new(1,1,1); btnLeft.Text="AUTO LEFT"
    btnLeft.Parent=toggleBarContainer; Instance.new("UICorner",btnLeft).CornerRadius=UDim.new(0,6)
    local xInputs={}; local zInputs={}; local speedInputs={}
    local function refreshToggleVisual()
        if selectedDir=="right" then
            btnRight.BackgroundColor3=Color3.fromRGB(255,185,0)
            btnLeft.BackgroundColor3=Color3.fromRGB(20,25,40); fs.Color=Color3.fromRGB(255,185,0)
        else
            btnRight.BackgroundColor3=Color3.fromRGB(20,25,40)
            btnLeft.BackgroundColor3=Color3.fromRGB(200,90,0); fs.Color=Color3.fromRGB(200,90,0)
        end
    end
    local function updateInputsForSet(pts)
        for i=1,N do
            if xInputs[i] then xInputs[i].Text=tostring(pts[i].x) end
            if zInputs[i] then zInputs[i].Text=tostring(pts[i].z) end
            if speedInputs[i] then speedInputs[i].Text=tostring(pts[i].speed or 58) end
        end
    end
    local setNameLbl
    local function switchTo(dir)
        if selectedDir==dir then return end
        selectedDir=dir; activeEdit=(dir=="right") and editPointsA or editPointsB
        awShared.dir = dir  -- sync untuk post-TP walk
        refreshToggleVisual(); buildMarkers(activeEdit); updateInputsForSet(activeEdit)
        if setNameLbl then
            setNameLbl.Text="Points — "..(dir=="right" and "Auto Right" or "Auto Left")
        end
    end
    refreshToggleVisual()
    btnRight.MouseButton1Click:Connect(function() switchTo("right") end)
    btnLeft.MouseButton1Click:Connect(function() switchTo("left") end)
    local contY=toggleBarY+TBH+PAD
    local pointsContainer=Instance.new("Frame")
    pointsContainer.Size=UDim2.new(1,0,0,28+N*RH+PAD+RH+PAD+BH)
    pointsContainer.Position=UDim2.new(0,0,0,contY); pointsContainer.BackgroundTransparency=1
    pointsContainer.Parent=frame
    local function makeInput(parent,px,py,defText,col)
        local tb=Instance.new("TextBox"); tb.Size=UDim2.new(0,IW,0,IH)
        tb.Position=UDim2.new(0,px,0,py); tb.BackgroundColor3=Color3.fromRGB(10,12,20)
        tb.TextColor3=Color3.new(1,1,1); tb.Font=Enum.Font.GothamBold; tb.TextSize=10
        tb.Text=defText; tb.ClearTextOnFocus=false; tb.Parent=parent
        Instance.new("UICorner",tb).CornerRadius=UDim.new(0,4)
        local st=Instance.new("UIStroke",tb); st.Color=col or Color3.fromRGB(180,120,0); st.Thickness=1
        return tb
    end
    setNameLbl=Instance.new("TextLabel"); setNameLbl.Size=UDim2.new(1,-10,0,14)
    setNameLbl.Position=UDim2.new(0,5,0,0); setNameLbl.BackgroundTransparency=1
    setNameLbl.Font=Enum.Font.GothamBold; setNameLbl.TextSize=9
    setNameLbl.TextColor3=Color3.fromRGB(180,180,180)
    setNameLbl.Text="Points — "..(selectedDir=="right" and "Auto Right" or "Auto Left")
    setNameLbl.TextXAlignment=Enum.TextXAlignment.Center; setNameLbl.Parent=pointsContainer
    local function makeColHdr(parent, px, txt, col)
        local lh=Instance.new("TextLabel"); lh.Size=UDim2.new(0,IW,0,12)
        lh.Position=UDim2.new(0,px,0,14); lh.BackgroundTransparency=1
        lh.Font=Enum.Font.GothamBold; lh.TextSize=8
        lh.TextColor3=col; lh.TextXAlignment=Enum.TextXAlignment.Center
        lh.Text=txt; lh.Parent=parent
    end
    makeColHdr(pointsContainer,46,"X",Color3.fromRGB(130,180,255))
    makeColHdr(pointsContainer,94,"Z",Color3.fromRGB(130,180,255))
    makeColHdr(pointsContainer,142,"Spd",Color3.fromRGB(100,220,100))
    for i=1,N do
        local col=getMarkerColors()[i]; local ry=(i-1)*RH+28; local iy=math.floor((RH-2-IH)/2)
        local rowBg=Instance.new("Frame"); rowBg.Size=UDim2.new(1,-10,0,RH-2)
        rowBg.Position=UDim2.new(0,5,0,ry+1); rowBg.BackgroundColor3=Color3.fromRGB(14,18,30)
        rowBg.BackgroundTransparency=0.1; rowBg.Parent=pointsContainer
        Instance.new("UICorner",rowBg).CornerRadius=UDim.new(0,6)
        local dot=Instance.new("Frame"); dot.Size=UDim2.new(0,6,0,6)
        dot.Position=UDim2.new(0,6,0.5,-3); dot.BackgroundColor3=col
        dot.BorderSizePixel=0; dot.Parent=rowBg
        Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
        local ptLbl=Instance.new("TextLabel"); ptLbl.Size=UDim2.new(0,28,1,0)
        ptLbl.Position=UDim2.new(0,16,0,0); ptLbl.BackgroundTransparency=1
        ptLbl.Font=Enum.Font.GothamBold; ptLbl.TextSize=11; ptLbl.TextColor3=Color3.new(1,1,1)
        ptLbl.TextStrokeTransparency=1; ptLbl.Text="P"..i
        ptLbl.TextXAlignment=Enum.TextXAlignment.Left; ptLbl.Parent=rowBg
        local xTB=makeInput(rowBg,46,iy,tostring(activeEdit[i].x),col)
        local zTB=makeInput(rowBg,94,iy,tostring(activeEdit[i].z),col)
        local sTB=makeInput(rowBg,142,iy,tostring(activeEdit[i].speed or 58),Color3.fromRGB(0,200,100))
        xInputs[i]=xTB; zInputs[i]=zTB; speedInputs[i]=sTB
        local idx=i
        xTB.FocusLost:Connect(function()
            local n=tonumber(xTB.Text)
            if n then activeEdit[idx].x=n; buildMarkers(activeEdit)
                if autoWalkWaypoints and autoWalkWaypoints[idx] then
                    autoWalkWaypoints[idx].position=Vector3.new(activeEdit[idx].x,activeEdit[idx].y,activeEdit[idx].z)
                end
            else xTB.Text=tostring(activeEdit[idx].x) end
        end)
        zTB.FocusLost:Connect(function()
            local n=tonumber(zTB.Text)
            if n then activeEdit[idx].z=n; buildMarkers(activeEdit)
                if autoWalkWaypoints and autoWalkWaypoints[idx] then
                    autoWalkWaypoints[idx].position=Vector3.new(activeEdit[idx].x,activeEdit[idx].y,activeEdit[idx].z)
                end
            else zTB.Text=tostring(activeEdit[idx].z) end
        end)
        sTB.FocusLost:Connect(function()
            local n=tonumber(sTB.Text)
            if n and n>=1 and n<=300 then
                activeEdit[idx].speed=n
                if autoWalkWaypoints and autoWalkWaypoints[idx] then
                    autoWalkWaypoints[idx].speed=n
                end
            else sTB.Text=tostring(activeEdit[idx].speed or 58) end
        end)
    end
    local dRy=28+N*RH+PAD
    local delayBg=Instance.new("Frame"); delayBg.Size=UDim2.new(1,-10,0,RH-2)
    delayBg.Position=UDim2.new(0,5,0,dRy+1); delayBg.BackgroundColor3=Color3.fromRGB(14,18,30)
    delayBg.BackgroundTransparency=0.1; delayBg.Parent=pointsContainer
    Instance.new("UICorner",delayBg).CornerRadius=UDim.new(0,6)
    local dlbl=Instance.new("TextLabel"); dlbl.Size=UDim2.new(0,90,1,0)
    dlbl.Position=UDim2.new(0,8,0,0); dlbl.BackgroundTransparency=1
    dlbl.Font=Enum.Font.GothamBold; dlbl.TextSize=10; dlbl.TextColor3=Color3.fromRGB(255,185,0)
    dlbl.Text="Delay (s):"; dlbl.TextXAlignment=Enum.TextXAlignment.Left; dlbl.Parent=delayBg
    local delayTB=makeInput(delayBg,113,math.floor((RH-2-IH)/2),tostring(savedDelay),Color3.fromRGB(255,185,0))
    delayTB.FocusLost:Connect(function()
        local n=tonumber(delayTB.Text)
        if n and n>=0 and n<=5 then walkDelay=n; savedDelay=n else delayTB.Text=tostring(walkDelay) end
    end)
    local saveRy=28+N*RH+PAD+RH+PAD
    local saveBtn=Instance.new("TextButton"); saveBtn.Size=UDim2.new(1,-10,0,BH)
    saveBtn.Position=UDim2.new(0,5,0,saveRy); saveBtn.Text="SAVE CONFIG"
    saveBtn.Font=Enum.Font.GothamBold; saveBtn.TextSize=11; saveBtn.TextColor3=Color3.new(1,1,1)
    saveBtn.BackgroundColor3=Color3.fromRGB(0,160,80); saveBtn.Parent=pointsContainer
    Instance.new("UICorner",saveBtn).CornerRadius=UDim.new(0,6)
    saveBtn.MouseButton1Click:Connect(function()
        savedDelay=walkDelay; saveWalkConfig(); saveBtn.Text="SAVED!"
        saveBtn.BackgroundColor3=Color3.fromRGB(30,200,100)
        task.delay(1.5,function() saveBtn.Text="SAVE CONFIG"; saveBtn.BackgroundColor3=Color3.fromRGB(0,160,80) end)
    end)
    saveAutoWalkPos = function()
        local ap = frame.AbsolutePosition
        uiPositions.autoWalk = {x = ap.X, y = ap.Y, open = panelOpen}
        pcall(saveUIPositions)
    end
    local function updatePanel()
        arrowLbl.Text=panelOpen and "-" or "+"
        pointsContainer.Visible=panelOpen; toggleBarContainer.Visible=panelOpen
        frame.Size=UDim2.new(0,FW,0,getHeight())
        walkGui.DisplayOrder = panelOpen and 10 or 1
        saveAutoWalkPos()
    end
    walkGui.DisplayOrder = panelOpen and 10 or 1
    titleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.Touch
        or inp.UserInputType==Enum.UserInputType.MouseButton1 then
            panelOpen=not panelOpen; updatePanel()
        end
    end)
    local currentWaypoint=1; local moving=false; local walkConn; local processing=false
    local function stopWalk()
        if walkConn then walkConn:Disconnect(); walkConn=nil end
        moving=false; processing=false; btn.Text="PLAY"; btn.BackgroundColor3=Color3.fromRGB(255,185,0)
        if statusLbl.Text~="FINISHED!" then
            statusLbl.Text="Press PLAY to begin"; statusLbl.TextColor3=Color3.fromRGB(150,150,150)
        end
        resetMarkerSizes()
    end
    local function moveToWaypoint()
        if walkConn then walkConn:Disconnect() end
        walkConn=RunService.Stepped:Connect(function()
            if not moving or processing then return end
            local char=lp.Character; local root=char and char:FindFirstChild("HumanoidRootPart")
            if not root then return end
            local wps=autoWalkWaypoints; if not wps then return end
            local wp=wps[currentWaypoint]; if not wp then return end
            highlightMarker(currentWaypoint)
            -- XZ-only distance: Y diabaikan supaya Float tidak ganggu advance waypoint
            local dist=(Vector3.new(root.Position.X,0,root.Position.Z)-Vector3.new(wp.position.X,0,wp.position.Z)).Magnitude
            if dist<5 then
                if currentWaypoint==#wps then
                    statusLbl.Text="FINISHED!"; statusLbl.TextColor3=Color3.fromRGB(67,181,129)
                    stopWalk(); return
                end
                local isP2=(currentWaypoint==2); processing=true; currentWaypoint+=1
                statusLbl.Text="Point "..currentWaypoint.." / "..#wps
                statusLbl.TextColor3=Color3.fromRGB(255,165,0)
                if isP2 and walkDelay>0 then task.delay(walkDelay,function() processing=false end)
                else processing=false end
            else
                -- dir XZ-only: Y diabaikan supaya saat float kecepatan tidak berkurang
                local flatTarget = Vector3.new(wp.position.X, root.Position.Y, wp.position.Z)
                local dir = (flatTarget - root.Position).Unit
                root.Velocity=Vector3.new(dir.X*wp.speed,root.Velocity.Y,dir.Z*wp.speed)
            end
        end)
    end
    local function startWalk()
        if not lp.Character or not lp.Character:FindFirstChild("HumanoidRootPart") then return end
        autoWalkWaypoints={}
        for _,ep in ipairs(activeEdit) do
            table.insert(autoWalkWaypoints,{position=Vector3.new(ep.x,ep.y,ep.z),speed=ep.speed})
        end
        moving=true; processing=false; currentWaypoint=1
        btn.Text="STOP"; btn.BackgroundColor3=Color3.fromRGB(200,30,30)
        statusLbl.Text="["..string.upper(selectedDir).."] P1 / "..#autoWalkWaypoints
        statusLbl.TextColor3=Color3.fromRGB(255,90,90); moveToWaypoint()
    end
    btn.MouseButton1Click:Connect(function() if moving then stopWalk() else startWalk() end end)
    local respawnConn=lp.CharacterAdded:Connect(function() if moving then stopWalk() end end)
    walkGui.AncestryChanged:Connect(function()
        if not walkGui.Parent then
            if walkConn then walkConn:Disconnect() end
            if respawnConn then respawnConn:Disconnect() end
            pcall(function() if markerFolder and markerFolder.Parent then markerFolder:Destroy() end end)
        end
    end)
end

local function destroyAutoWalkGui()
    if walkGui then
        local frame = walkGui:FindFirstChildWhichIsA("Frame")
        if frame then
            local ap = frame.AbsolutePosition
            uiPositions.autoWalk = {x = ap.X, y = ap.Y}
            pcall(saveUIPositions)
        end
        walkGui:Destroy(); walkGui = nil
    end
end

-- =====================================================
-- BAT TELEPORT GUI
-- =====================================================
local function createBatTeleportGui()
    if batTeleportGui then return end
    pcall(function()
        local old = CoreGui:FindFirstChild("BatTeleportGui_VH")
        if old then old:Destroy() end
    end)
    batTeleportGui = Instance.new("ScreenGui")
    batTeleportGui.Name         = "BatTeleportGui_VH"
    batTeleportGui.ResetOnSpawn = false
    batTeleportGui.Parent       = CoreGui

    local FW  = 142
    local TH  = 47
    local BH  = 47
    local DRH = 30
    local PAD = 5

    local savedPos  = uiPositions.batTeleport
    local panelOpen = (savedPos and savedPos.open ~= nil) and savedPos.open or false

    local function getHeight()
        return panelOpen and (TH + PAD + BH + PAD + DRH + PAD) or TH
    end

    local vp  = workspace.CurrentCamera.ViewportSize
    local btX = savedPos and savedPos.x or (vp.X/2 - FW/2)
    local btY = savedPos and savedPos.y or (vp.Y * 0.65)

    -- Outer frame
    local frame = Instance.new("Frame")
    frame.Size               = UDim2.new(0, FW, 0, getHeight())
    frame.Position           = UDim2.new(0, btX, 0, btY)
    frame.BackgroundColor3   = Color3.fromRGB(10, 12, 20)
    frame.BackgroundTransparency = 0.08
    frame.Active             = true
    frame.ClipsDescendants   = true
    frame.Parent             = batTeleportGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local batStroke = Instance.new("UIStroke", frame)
    batStroke.Color     = Color3.fromRGB(255, 185, 0)
    batStroke.Thickness = 1.5

    -- Top row: main button (status + cancel when walking)
    local batBtn = Instance.new("TextButton")
    batBtn.Size               = UDim2.new(1, -32, 0, TH)
    batBtn.Position           = UDim2.new(0, 0, 0, 0)
    batBtn.BackgroundTransparency = 1
    batBtn.Font               = Enum.Font.GothamBold
    batBtn.TextSize           = 16
    batBtn.TextColor3         = Color3.new(1, 1, 1)
    batBtn.Text               = "BAT TP"
    batBtn.Parent             = frame

    -- Top row: arrow expand/collapse
    local arrowBtn = Instance.new("TextButton")
    arrowBtn.Size               = UDim2.new(0, 30, 0, TH)
    arrowBtn.Position           = UDim2.new(1, -30, 0, 0)
    arrowBtn.BackgroundTransparency = 1
    arrowBtn.Font               = Enum.Font.GothamBold
    arrowBtn.TextSize           = 11
    arrowBtn.TextColor3         = Color3.fromRGB(200, 200, 200)
    arrowBtn.Text               = panelOpen and "^" or "v"
    arrowBtn.Parent             = frame

    -- Side selector
    local sideBtn = Instance.new("TextButton")
    sideBtn.Size               = UDim2.new(1, -10, 0, BH)
    sideBtn.Position           = UDim2.new(0, 5, 0, TH + PAD)
    sideBtn.BackgroundColor3   = Color3.fromRGB(10, 12, 20)
    sideBtn.Font               = Enum.Font.GothamBold
    sideBtn.TextSize           = 16
    sideBtn.TextColor3         = Color3.new(1, 1, 1)
    sideBtn.Text               = batSelectedSide == "B" and "RIGHT" or "LEFT"
    sideBtn.Visible            = panelOpen
    sideBtn.Parent             = frame
    Instance.new("UICorner", sideBtn).CornerRadius = UDim.new(0, 6)
    local sideStroke = Instance.new("UIStroke", sideBtn)
    sideStroke.Color     = Color3.fromRGB(255, 185, 0)
    sideStroke.Thickness = 1.5

    -- Walk Delay row
    local delayRow = Instance.new("Frame")
    delayRow.Size               = UDim2.new(1, -10, 0, DRH)
    delayRow.Position           = UDim2.new(0, 5, 0, TH + PAD + BH + PAD)
    delayRow.BackgroundColor3   = Color3.fromRGB(14, 18, 30)
    delayRow.BackgroundTransparency = 0.1
    delayRow.BorderSizePixel    = 0
    delayRow.Visible            = panelOpen
    delayRow.Parent             = frame
    Instance.new("UICorner", delayRow).CornerRadius = UDim.new(0, 6)

    local delayLbl = Instance.new("TextLabel")
    delayLbl.Size                 = UDim2.new(0, 78, 1, 0)
    delayLbl.Position             = UDim2.new(0, 8, 0, 0)
    delayLbl.BackgroundTransparency = 1
    delayLbl.Text                 = "Walk Delay"
    delayLbl.Font                 = Enum.Font.GothamBold
    delayLbl.TextSize             = 11
    delayLbl.TextColor3           = Color3.fromRGB(200, 200, 200)
    delayLbl.TextXAlignment       = Enum.TextXAlignment.Left
    delayLbl.Parent               = delayRow

    local delayBox = Instance.new("TextBox")
    delayBox.Size               = UDim2.new(0, 40, 0, 20)
    delayBox.Position           = UDim2.new(1, -46, 0.5, -10)
    delayBox.BackgroundColor3   = Color3.fromRGB(10, 12, 20)
    delayBox.Text               = tostring(awPostTpDelay)
    delayBox.Font               = Enum.Font.GothamBold
    delayBox.TextSize           = 11
    delayBox.TextColor3         = Color3.fromRGB(255, 185, 0)
    delayBox.TextXAlignment     = Enum.TextXAlignment.Center
    delayBox.ClearTextOnFocus   = false
    delayBox.BorderSizePixel    = 0
    delayBox.Parent             = delayRow
    Instance.new("UICorner", delayBox).CornerRadius = UDim.new(0, 4)
    Instance.new("UIStroke", delayBox).Color = Color3.fromRGB(255, 185, 0)

    delayBox.FocusLost:Connect(function()
        local n = tonumber(delayBox.Text)
        if n and n >= 0 and n <= 10 then
            awPostTpDelay = n
        end
        delayBox.Text = tostring(awPostTpDelay)
    end)

    -- Save helper
    local function saveBatPos()
        local ap = frame.AbsolutePosition
        uiPositions.batTeleport = {x = ap.X, y = ap.Y, open = panelOpen}
        pcall(saveUIPositions)
    end

    -- Expand / collapse
    local function updatePanel()
        arrowBtn.Text    = panelOpen and "^" or "v"
        sideBtn.Visible  = panelOpen
        delayRow.Visible = panelOpen
        frame.Size       = UDim2.new(0, FW, 0, getHeight())
        batTeleportGui.DisplayOrder = panelOpen and 10 or 1
        saveBatPos()
    end

    batTeleportGui.DisplayOrder = panelOpen and 10 or 1

    arrowBtn.MouseButton1Click:Connect(function()
        panelOpen = not panelOpen
        updatePanel()
    end)

    -- Side selector: toggle RIGHT / LEFT
    sideBtn.MouseButton1Click:Connect(function()
        batSelectedSide = (batSelectedSide == "B") and "A" or "B"
        sideBtn.Text = batSelectedSide == "B" and "RIGHT" or "LEFT"
        pcall(mainSaveConfig)
    end)

    -- Walking visual: matches TP GUI pattern exactly
    local function setWalkingVisual(walking)
        if walking then
            batBtn.Text       = "BAT TP (WALK)"
            batBtn.TextColor3 = Color3.fromRGB(255, 220, 0)
            batStroke.Color   = Color3.fromRGB(255, 220, 0)
        else
            batBtn.Text       = "BAT TP"
            batBtn.TextColor3 = Color3.new(1, 1, 1)
            batStroke.Color   = Color3.fromRGB(255, 185, 0)
        end
    end

    -- Callbacks wired up by doTeleport
    _batOnWalkStart = function()
        setWalkingVisual(true)
        batStroke.Color = Color3.fromRGB(0, 220, 100)
        task.delay(0.3, function()
            if awPostTpRunning then
                batStroke.Color = Color3.fromRGB(255, 220, 0)
            else
                setWalkingVisual(false)
            end
        end)
    end
    _batOnWalkEnd = function() setWalkingVisual(false) end

    -- Click main button while walking = cancel
    batBtn.MouseButton1Click:Connect(function()
        if awPostTpRunning then
            cancelPostTpWalk()
            setWalkingVisual(false)
        end
    end)

    -- Draggable
    makeDraggable(frame, function(_ap)
        task.defer(saveBatPos)
    end)
end

local function destroyBatTeleportGui()
    if batTeleportGui then
        local frame = batTeleportGui:FindFirstChildWhichIsA("Frame")
        if frame then
            local ap = frame.AbsolutePosition
            uiPositions.batTeleport = {x = ap.X, y = ap.Y}
            pcall(saveUIPositions)
        end
        batTeleportGui:Destroy(); batTeleportGui = nil
    end
    _batOnWalkStart = nil
    _batOnWalkEnd   = nil
end

-- =====================================================
-- TP — MANUAL TELEPORT GUI
-- Same points as Bat Teleport (BAT_SEQ_A / BAT_SEQ_B)
-- UI style: collapsible panel (like Bat Teleport GUI)
--   • Collapsed  → shows only the "TP" title bar
--   • Expanded   → shows TP RIGHT / TP LEFT buttons
-- Clicking a side button BOTH selects the side AND
-- immediately teleports to that side's first point.
-- =====================================================
local tpEnabled      = false
local tpGui          = nil
local tpSelectedSide = "B"   -- "B" = Right,  "A" = Left

local function doManualTP(side)
    local char = lp.Character; if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
    local humTP = char:FindFirstChildOfClass("Humanoid")
    -- Briefly clear ragdoll state so the teleport sticks
    pcall(function()
        local now = workspace:GetServerTimeNow()
        lp:SetAttribute("RagdollEndTime", now)
    end)
    if humTP and humTP.Health > 0 then
        pcall(function() humTP:ChangeState(Enum.HumanoidStateType.Running) end)
    end
    pcall(function()
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
    local seq = (side == "A") and BAT_SEQ_A or BAT_SEQ_B
    root:PivotTo(CFrame.new(seq.tp1))
    task.wait(0.2)
    if char.Parent then
        root:PivotTo(CFrame.new(seq.tp2))
    end
    -- auto-walk ke P3-5 setelah TP selesai
    startPostTpWalk(side)
end

local function createTpGui()
    if tpGui then return end
    pcall(function()
        local old = CoreGui:FindFirstChild("TpGui_VH")
        if old then old:Destroy() end
    end)
    tpGui = Instance.new("ScreenGui")
    tpGui.Name         = "TpGui_VH"
    tpGui.ResetOnSpawn = false
    tpGui.Parent       = CoreGui

    local FW   = 142
    local TH   = 47
    local BH   = 47
    local DRH  = 30
    local PAD  = 5

    local savedPos  = uiPositions.tpGui
    local panelOpen = (savedPos and savedPos.open ~= nil) and savedPos.open or false

    local function getHeight()
        return panelOpen and (TH + PAD + BH + PAD + DRH + PAD) or TH
    end

    local vp  = workspace.CurrentCamera.ViewportSize
    local tpX = savedPos and savedPos.x or (vp.X/2 - FW/2)
    local tpY = savedPos and savedPos.y or (vp.Y * 0.85)

    -- ── Outer frame ─────────────────────────────────
    local frame = Instance.new("Frame")
    frame.Size               = UDim2.new(0, FW, 0, getHeight())
    frame.Position           = UDim2.new(0, tpX, 0, tpY)
    frame.BackgroundColor3   = Color3.fromRGB(10, 12, 20)
    frame.BackgroundTransparency = 0.08
    frame.Active             = true
    frame.ClipsDescendants   = true
    frame.Parent             = tpGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local tpStroke = Instance.new("UIStroke", frame)
    tpStroke.Color     = Color3.fromRGB(255, 185, 0)
    tpStroke.Thickness = 1.5

    -- ── Top row ─────────────────────────────────────
    local tpBtn = Instance.new("TextButton")
    tpBtn.Size               = UDim2.new(1, -32, 0, TH)
    tpBtn.Position           = UDim2.new(0, 0, 0, 0)
    tpBtn.BackgroundTransparency = 1
    tpBtn.Font               = Enum.Font.GothamBold
    tpBtn.TextSize           = 16
    tpBtn.TextColor3         = Color3.new(1, 1, 1)
    tpBtn.Text               = "TP"
    tpBtn.Parent             = frame

    local arrowBtn = Instance.new("TextButton")
    arrowBtn.Size               = UDim2.new(0, 30, 0, TH)
    arrowBtn.Position           = UDim2.new(1, -30, 0, 0)
    arrowBtn.BackgroundTransparency = 1
    arrowBtn.Font               = Enum.Font.GothamBold
    arrowBtn.TextSize           = 11
    arrowBtn.TextColor3         = Color3.fromRGB(200, 200, 200)
    arrowBtn.Text               = panelOpen and "▲" or "▼"
    arrowBtn.Parent             = frame

    -- ── Side selector ────────────────────────────────
    local sideBtn = Instance.new("TextButton")
    sideBtn.Size               = UDim2.new(1, -10, 0, BH)
    sideBtn.Position           = UDim2.new(0, 5, 0, TH + PAD)
    sideBtn.BackgroundColor3   = Color3.fromRGB(10, 12, 20)
    sideBtn.Font               = Enum.Font.GothamBold
    sideBtn.TextSize           = 16
    sideBtn.TextColor3         = Color3.new(1, 1, 1)
    sideBtn.Text               = tpSelectedSide == "B" and "RIGHT" or "LEFT"
    sideBtn.Visible            = panelOpen
    sideBtn.Parent             = frame
    Instance.new("UICorner", sideBtn).CornerRadius = UDim.new(0, 6)
    local sideStroke = Instance.new("UIStroke", sideBtn)
    sideStroke.Color     = Color3.fromRGB(255, 185, 0)
    sideStroke.Thickness = 1.5

    -- ── Delay row ────────────────────────────────────
    local delayRow = Instance.new("Frame")
    delayRow.Size               = UDim2.new(1, -10, 0, DRH)
    delayRow.Position           = UDim2.new(0, 5, 0, TH + PAD + BH + PAD)
    delayRow.BackgroundColor3   = Color3.fromRGB(14, 18, 30)
    delayRow.BackgroundTransparency = 0.1
    delayRow.BorderSizePixel    = 0
    delayRow.Visible            = panelOpen
    delayRow.Parent             = frame
    Instance.new("UICorner", delayRow).CornerRadius = UDim.new(0, 6)

    local delayLbl = Instance.new("TextLabel")
    delayLbl.Size                 = UDim2.new(0, 78, 1, 0)
    delayLbl.Position             = UDim2.new(0, 8, 0, 0)
    delayLbl.BackgroundTransparency = 1
    delayLbl.Text                 = "Walk Delay"
    delayLbl.Font                 = Enum.Font.GothamBold
    delayLbl.TextSize             = 11
    delayLbl.TextColor3           = Color3.fromRGB(200, 200, 200)
    delayLbl.TextXAlignment       = Enum.TextXAlignment.Left
    delayLbl.Parent               = delayRow

    local delayBox = Instance.new("TextBox")
    delayBox.Size               = UDim2.new(0, 40, 0, 20)
    delayBox.Position           = UDim2.new(1, -46, 0.5, -10)
    delayBox.BackgroundColor3   = Color3.fromRGB(10, 12, 20)
    delayBox.Text               = tostring(awPostTpDelay)
    delayBox.Font               = Enum.Font.GothamBold
    delayBox.TextSize           = 11
    delayBox.TextColor3         = Color3.fromRGB(255, 185, 0)
    delayBox.TextXAlignment     = Enum.TextXAlignment.Center
    delayBox.ClearTextOnFocus   = false
    delayBox.BorderSizePixel    = 0
    delayBox.Parent             = delayRow
    Instance.new("UICorner", delayBox).CornerRadius = UDim.new(0, 4)
    Instance.new("UIStroke", delayBox).Color = Color3.fromRGB(255, 185, 0)

    delayBox.FocusLost:Connect(function()
        local n = tonumber(delayBox.Text)
        if n and n >= 0 and n <= 10 then
            awPostTpDelay = n
        end
        delayBox.Text = tostring(awPostTpDelay)
    end)

    -- ── Save helper ──────────────────────────────────
    local function saveTpPos()
        local ap = frame.AbsolutePosition
        uiPositions.tpGui = {x = ap.X, y = ap.Y, open = panelOpen}
        pcall(saveUIPositions)
    end

    -- ── Expand / collapse ────────────────────────────
    local function updatePanel()
        arrowBtn.Text      = panelOpen and "▲" or "▼"
        sideBtn.Visible    = panelOpen
        delayRow.Visible   = panelOpen
        frame.Size         = UDim2.new(0, FW, 0, getHeight())
        tpGui.DisplayOrder = panelOpen and 10 or 1
        saveTpPos()
    end

    tpGui.DisplayOrder = panelOpen and 10 or 1

    arrowBtn.MouseButton1Click:Connect(function()
        panelOpen = not panelOpen
        updatePanel()
    end)

    -- ── Side selector: toggle RIGHT/LEFT ─────────────
    sideBtn.MouseButton1Click:Connect(function()
        tpSelectedSide = (tpSelectedSide == "B") and "A" or "B"
        sideBtn.Text = tpSelectedSide == "B" and "RIGHT" or "LEFT"
    end)

    -- ── TP button: TP → walk, saat walking klik = cancel ─
    local function setWalkingVisual(walking)
        if walking then
            tpBtn.Text       = "TP (WALK)"
            tpBtn.TextColor3 = Color3.fromRGB(255, 220, 0)
            tpStroke.Color   = Color3.fromRGB(255, 220, 0)
        else
            tpBtn.Text       = "TP"
            tpBtn.TextColor3 = Color3.new(1, 1, 1)
            tpStroke.Color   = Color3.fromRGB(255, 185, 0)
        end
    end

    -- callback dipanggil saat walk selesai / cancel dari luar
    awPostTpOnEnd = function() setWalkingVisual(false) end

    tpBtn.MouseButton1Click:Connect(function()
        if awPostTpRunning then
            -- sedang walk → cancel
            cancelPostTpWalk()
            setWalkingVisual(false)
        else
            -- belum walk → TP + mulai walk
            doManualTP(tpSelectedSide)
            setWalkingVisual(true)
            tpStroke.Color = Color3.fromRGB(0, 220, 100)
            task.delay(0.3, function()
                if not awPostTpRunning then
                    setWalkingVisual(false)
                else
                    tpStroke.Color = Color3.fromRGB(255, 220, 0)
                end
            end)
        end
    end)

    -- ── Draggable ────────────────────────────────────
    makeDraggable(frame, function(_ap)
        task.defer(saveTpPos)
    end)
end

local function destroyTpGui()
    tpEnabled = false
    if tpGui then
        local frame = tpGui:FindFirstChildWhichIsA("Frame")
        if frame then
            local ap = frame.AbsolutePosition
            uiPositions.tpGui = {x = ap.X, y = ap.Y}
            pcall(saveUIPositions)
        end
        tpGui:Destroy(); tpGui = nil
    end
end

local function CreateToggle(sectionName, text)
    local parentFrame = frames[sectionName]

    -- ── Input variables (Settings) ──
    if text == "Radius Auto Steal" and sectionName == "Settings" then
        local container = Instance.new("Frame"); container.Size = UDim2.new(1, -10, 0, 38)
        container.BackgroundColor3 = Color3.fromRGB(20, 25, 40); container.BorderSizePixel = 0
        container.Parent = parentFrame
        Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)

        local label = Instance.new("TextLabel"); label.Size = UDim2.new(0.6, 0, 1, 0)
        label.Position = UDim2.new(0, 12, 0, 0); label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold; label.TextSize = 13
        label.TextColor3 = Color3.new(1, 1, 1); label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = "Radius Auto Steal"; label.Parent = container

        local textbox = Instance.new("TextBox"); textbox.Size = UDim2.new(0, 60, 0, 24)
        textbox.Position = UDim2.new(1, -72, 0.5, -12); textbox.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
        textbox.TextColor3 = Color3.fromRGB(255, 185, 0); textbox.Font = Enum.Font.GothamBold
        textbox.TextSize = 12; textbox.Text = tostring(grabRadius)
        textbox.ClearTextOnFocus = false; textbox.Parent = container
        Instance.new("UICorner", textbox).CornerRadius = UDim.new(0, 4)

        textbox.FocusLost:Connect(function()
            local num = tonumber(textbox.Text)
            if num and num > 0 and num <= 1000 then
                grabRadius = num; STEAL_RADIUS = num; pcall(mainSaveConfig)
            else textbox.Text = tostring(grabRadius) end
        end)
        tbStealRadius = textbox
        return
    end

    -- ── Toggle normal ──────────────────────────────
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -10, 0, 38)
    container.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
    container.BorderSizePixel = 0
    container.Parent = parentFrame
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold; label.TextSize = 13
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text; label.Parent = container

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 42, 0, 20)
    button.Position = UDim2.new(1, -54, 0.5, -10)
    button.BackgroundColor3 = Color3.fromRGB(40, 45, 65)
    button.Text = ""; button.Parent = container
    Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 16, 0, 16)
    circle.Position = UDim2.new(0, 2, 0.5, -8)
    circle.BackgroundColor3 = Color3.new(1, 1, 1)
    circle.Parent = button
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local enabled = false

    local function runFeature(state)
        if text == "Speed Customizer" then
            if state then createSpeedCustomizerGui() else destroySpeedCustomizerGui() end
        elseif text == "Optimizer" then
            if state then enableOptimizer() else disableOptimizer() end
        elseif text == "Anti Ragdoll" then
            if state and antiRagdoll2Enabled then
                stopAntiRagdoll2(); if toggleSetters["Anti Ragdoll 2"] then toggleSetters["Anti Ragdoll 2"](false) end
            end
            if state then _enableAR1() else _disableAR1() end
        elseif text == "Anti Ragdoll 2" then
            if state and antiRagdollMode then
                _disableAR1(); if toggleSetters["Anti Ragdoll"] then toggleSetters["Anti Ragdoll"](false) end
            end
            antiRagdoll2Enabled = state
            if state then startAntiRagdoll2() else stopAntiRagdoll2() end
        elseif text == "No Player Collision" then
            noClipEnabled = state
            if state then enableNoClip() else disableNoClip() end
        elseif text == "Anti FPS Devourer" then
            if state then enableAntiFPSDevourer() else disableAntiFPSDevourer() end
        elseif text == "Infinite Jump" then infiniteJumpEnabled = state
        elseif text == "No Walk Animation" then
            local char = lp.Character; if not char then return end
            noWalkEnabled = state
            if state then
                local animate = char:FindFirstChild("Animate")
                if animate then savedAnimate = animate; animate.Disabled = true end
                local humNW = char:FindFirstChildOfClass("Humanoid")
                if humNW then for _, t in ipairs(humNW:GetPlayingAnimationTracks()) do t:Stop() end end
            else
                if savedAnimate then savedAnimate.Disabled = false; savedAnimate = nil end
            end
        elseif text == "Auto Bat" then
            autoBatActive = state
            if state then
                if autoBatLoop then autoBatActive = false; autoBatLoop = nil end
                autoBatActive = true
                autoBatLoop = task.spawn(function()
                    while autoBatActive do
                        local char = lp.Character
                        if char then
                            local tool = char:FindFirstChild("Bat")
                            if tool and tool:IsA("Tool") then pcall(function() tool:Activate() end) end
                        end
                        task.wait(0.4)
                    end
                end)
            else autoBatActive = false end
        elseif text == "Bat Teleport" then
            if state then
                batTeleportEnabled = true
                createBatTeleportGui()
                local char = lp.Character; if char then setupBatTeleport(char) end
            else disableBatTeleport(); destroyBatTeleportGui() end
        elseif text == "TP" then
            tpEnabled = state
            if state then createTpGui() else destroyTpGui() end
        elseif text == "Lock Target" then
            if state then createLockGui() else destroyLockGui() end
        elseif text == "Float" then
            if state then createFloatGui() else destroyFloatGui() end
        elseif text == "Auto Medusa" then AutoMedusaEnabled = state; InitMedusa()
        elseif text == "Melee Aimbot" then
            meleeEnabled = state
            if state then if character then createMeleeAimbot(character) end
            else disableMeleeAimbot() end
        elseif text == "Auto Walk" then
            autoWalkEnabled = state
            if state then createAutoWalkGui() else destroyAutoWalkGui() end
        elseif text == "Auto Steal" then
            autoStealEnabled = state
            if state then
                StealData = {}; isStealing = false
                startAutoSteal()
            else stopAutoSteal() end
        elseif text == "Lock UI" then
            uiLocked = state
        end
    end

    toggleSetters[text] = function(state)
        if state == enabled then return end
        enabled = state; toggleStates[text] = state
        if enabled then
            button.BackgroundColor3 = Color3.fromRGB(255, 185, 0)
            circle.Position = UDim2.new(1, -18, 0.5, -8)
        else
            button.BackgroundColor3 = Color3.fromRGB(40, 45, 65)
            circle.Position = UDim2.new(0, 2, 0.5, -8)
        end
        runFeature(state)
    end

    button.MouseButton1Click:Connect(function()
        enabled = not enabled; toggleStates[text] = enabled
        if enabled then
            TweenService:Create(button, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(255, 185, 0)}):Play()
            TweenService:Create(circle, TweenInfo.new(0.25), {Position = UDim2.new(1, -18, 0.5, -8)}):Play()
        else
            TweenService:Create(button, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(40, 45, 65)}):Play()
            TweenService:Create(circle, TweenInfo.new(0.25), {Position = UDim2.new(0, 2, 0.5, -8)}):Play()
        end
        runFeature(enabled); pcall(mainSaveConfig)
    end)
end

-- =====================================================
-- DAFTAR TOGGLE
-- =====================================================
local combatFuncs = {"Melee Aimbot","Auto Steal","Auto Walk","Lock Target","Auto Medusa","Auto Bat","Bat Teleport","TP"}
for _, f in ipairs(combatFuncs) do CreateToggle("Duels", f) end

local playerFuncs = {"Speed Customizer","No Walk Animation","Anti Ragdoll","Anti Ragdoll 2","No Player Collision","Float","Infinite Jump"}
for _, f in ipairs(playerFuncs) do CreateToggle("Player", f) end

local visualFuncs = {"Optimizer","Anti FPS Devourer"}
for _, f in ipairs(visualFuncs) do CreateToggle("Visual", f) end

local tbStealRadius = nil  -- diisi oleh CreateToggle "Radius Auto Steal"

CreateToggle("Settings", "Radius Auto Steal")
CreateToggle("Settings", "Lock UI")

local function createSettingInput(name, defaultValue, updateFunc)
    local parentFrame = frames["Settings"]
    local container = Instance.new("Frame"); container.Size = UDim2.new(1, -10, 0, 38)
    container.BackgroundColor3 = Color3.fromRGB(20, 25, 40); container.BorderSizePixel = 0
    container.Parent = parentFrame
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel"); label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0); label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold; label.TextSize = 13
    label.TextColor3 = Color3.new(1, 1, 1); label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = name; label.Parent = container

    local textbox = Instance.new("TextBox"); textbox.Size = UDim2.new(0, 60, 0, 24)
    textbox.Position = UDim2.new(1, -72, 0.5, -12); textbox.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
    textbox.TextColor3 = Color3.fromRGB(255, 185, 0); textbox.Font = Enum.Font.GothamBold
    textbox.TextSize = 12; textbox.Text = tostring(defaultValue)
    textbox.ClearTextOnFocus = false; textbox.Parent = container
    Instance.new("UICorner", textbox).CornerRadius = UDim.new(0, 4)

    textbox.FocusLost:Connect(function() updateFunc(textbox) end)
    return textbox
end

local tbDuration = createSettingInput("Steal Duration (s)", STEAL_DURATION, function(tb)
    local n = tonumber(tb.Text); if n and n >= 0.05 and n <= 5 then STEAL_DURATION = n; pcall(mainSaveConfig) else tb.Text = tostring(STEAL_DURATION) end
end)
task.spawn(function() task.wait(1.1); tbDuration.Text = tostring(STEAL_DURATION) end)

createSettingInput("Range Lock Target", LOCK_RADIUS, function(tb)
    local n = tonumber(tb.Text); if n and n > 5 and n <= 500 then LOCK_RADIUS = n; pcall(mainSaveConfig) else tb.Text = tostring(LOCK_RADIUS) end
end)

createSettingInput("Radio Auto Medusa", MEDUSA_RADIUS, function(tb)
    local n = tonumber(tb.Text)
    if n and n > 1 and n <= 200 then
        MEDUSA_RADIUS = n
        if medusaPart then medusaPart.Size = Vector3.new(0.05, MEDUSA_RADIUS*2, MEDUSA_RADIUS*2) end
        pcall(mainSaveConfig)
    else tb.Text = tostring(MEDUSA_RADIUS) end
end)

createSettingInput("Range Melee Aimbot", MELEE_RANGE, function(tb)
    local n = tonumber(tb.Text); if n and n > 1 and n <= 50 then MELEE_RANGE = n; pcall(mainSaveConfig) else tb.Text = tostring(MELEE_RANGE) end
end)

ShowSection("Duels")

-- =====================================================
-- OPEN / CLOSE HUB
-- =====================================================
local opened = false
toggleBtn.MouseButton1Click:Connect(function()
    opened = not opened
    if opened then
        TweenService:Create(hub, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 100, 0.5, -HUB_HEIGHT / 2)}):Play()
    else
        TweenService:Create(hub, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Position = UDim2.new(0, -HUB_WIDTH - 50, 0.5, -HUB_HEIGHT / 2)}):Play()
    end
end)

-- =====================================================
-- LOAD CONFIG SAAT EXECUTE
-- =====================================================
task.spawn(function()
    task.wait(1.0)
    mainLoadConfig()
    print("[Vincitore Duels] Config loaded")
end)
