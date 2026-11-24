-- United Muscles | Auto Farm UI v14 COMPLETO (Arceus X Neo Mobile)
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local lp = Players.LocalPlayer

-- ===== CONFIG =====
local TRAIN_SPEED = 20
local REBIRTH_SPEED = 3
local BURST_CAP = 100   -- máx. de disparos por frame (proteção contra congelar)
local RATE = {punch = 1/TRAIN_SPEED, weight = 1/TRAIN_SPEED, pushup = 1/TRAIN_SPEED,
              all = 1/TRAIN_SPEED, rebirth = 1/REBIRTH_SPEED}
local SPEED_VALUE = 200
local TAP_ENABLED = true
local TAP_INTERVAL = 0.12
local REC_SECONDS = 8   -- tempo de gravação

local KEYWORDS = {
    punch = {"punch", "soco", "punho", "fist", "attack", "hit"},
    weight = {"weight", "dumbbell", "barbell", "halter", "haltere", "peso", "lift", "train", "workout"},
    pushup = {"pushup", "push up", "push-up", "flex", "flexao", "flexão"},
    rebirth = {"rebirth", "renasc"},
}
local TOOL_WORDS = {
    punch = {"punch", "soco", "punho", "fist"},
    weight = {"weight", "dumbbell", "barbell", "halter", "haltere", "peso"},
    pushup = {"pushup", "push up", "flex"},
}
local STATION_WORDS = {"train", "bench", "supino", "weight", "dumbbell", "barbell", "press", "pushup", "push up",
    "pull", "chin", "bar", "barra", "squat", "agach", "treadmill", "esteira", "punching", "saco", "bag",
    "lift", "workout", "flex", "muscle", "gym", "ginasio", "ginásio"}
local BLACKLIST = {"shop", "loja", "buy", "compra", "rebirth", "renasc", "trade", "troca", "gem", "code",
    "codigo", "teleport", "portal", "egg", "pack", "pacote", "fight", "luta", "claim", "reward",
    "elevator", "elevador", "rei dos"}
-- Filtro leve: só ignora spam óbvio
local NOISE = {"camera", "ping", "heartbeat", "mouse", "analytic", "chat", "walk", "jump"}

local state = {punch = false, weight = false, pushup = false, all = false, rebirth = false,
               loop = false, speed = false, afk = false, kick = false}
local captured = {}
local ACTIONS = {"punch", "weight", "pushup"}
local recordedTrain, recordedRebirth = {}, {}
local recBuffer, recSeen, recTarget = nil, {}, nil
local replaying = false
local hookMethod, hookCalls = "nenhum", 0

-- ===== UI =====
pcall(function()
    for _, p in ipairs({gethui and gethui(), game:GetService("CoreGui"), lp:FindFirstChild("PlayerGui")}) do
        local o = p and p:FindFirstChild("UMHub")
        if o then o:Destroy() end
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "UMHub"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.IgnoreGuiInset = true

local function tryParent(p)
    if not p then return false end
    local ok = pcall(function() gui.Parent = p end)
    return ok and gui.Parent == p
end
local ok1, hui = pcall(function() return gethui and gethui() end)
if not (ok1 and tryParent(hui)) then
    local ok2, core = pcall(function() return game:GetService("CoreGui") end)
    if not (ok2 and tryParent(core)) then tryParent(lp:WaitForChild("PlayerGui")) end
end

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(240, 345)
main.Position = UDim2.new(0.5, -120, 0.04, 0)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 34)
title.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
title.BorderSizePixel = 0
title.Text = "United Muscles Hub"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = main
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -10, 0, 178)
scroll.Position = UDim2.new(0, 5, 0, 112)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.Parent = main
local layout = Instance.new("UIListLayout", scroll)
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
local pad = Instance.new("UIPadding", scroll)
pad.PaddingLeft = UDim.new(0, 5)
pad.PaddingRight = UDim.new(0, 9)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 48)
status.Position = UDim2.new(0, 10, 0, 294)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(200, 200, 200)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextWrapped = true
status.Text = "Caixas: número, 1k, 1m, 1e9, max ou inf."
status.Parent = main

local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.fromOffset(44, 44)
openBtn.Position = UDim2.new(0, 10, 0.5, 0)
openBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.Text = "UM"
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 14
openBtn.Parent = gui
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(1, 0)
openBtn.MouseButton1Click:Connect(function() main.Visible = not main.Visible end)

local function makeDraggable(handle, target)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                        startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end
makeDraggable(title, main)
makeDraggable(openBtn, openBtn)

local orderCount = 0
local function makeButton(text)
    orderCount += 1
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.LayoutOrder = orderCount
    btn.BackgroundColor3 = Color3.fromRGB(170, 50, 50)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.Text = text
    btn.BorderSizePixel = 0
    btn.Parent = scroll
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    return btn
end

local function setBtn(btn, text, on)
    btn.Text = text .. ": " .. (on and "ON" or "OFF")
    btn.BackgroundColor3 = on and Color3.fromRGB(50, 170, 80) or Color3.fromRGB(170, 50, 50)
end

local function makeToggle(text, key, onChange)
    local btn = makeButton(text .. ": OFF")
    btn.MouseButton1Click:Connect(function()
        state[key] = not state[key]
        setBtn(btn, text, state[key])
        if onChange then onChange(state[key]) end
    end)
    return btn
end

-- ===== Textboxes de velocidade (fixos no topo, sem limite) =====
local MULT = {k = 1e3, m = 1e6, b = 1e9, t = 1e12}
local INF_WORDS = {max = true, maximo = true, ["máximo"] = true, inf = true, infinito = true, infinity = true}

local function parseNum(s)
    s = (s:lower():gsub("%s", ""):gsub(",", "."))
    if INF_WORDS[s] then return math.huge end
    local num, suf = s:match("^([%d%.e%+%-]+)([kmbt]?)$")
    if not num then return nil end
    local n = tonumber(num)
    if not n then return nil end
    if suf ~= "" then n = n * MULT[suf] end
    if n <= 0 then return nil end
    return n
end

local function fmt(n)
    if n == math.huge then return "INF" end
    if n >= 1e6 then return string.format("%.3g", n) end
    if n == math.floor(n) then return tostring(math.floor(n)) end
    return string.format("%.2f", n)
end

local function makeSpeedBox(labelText, yPos, default, onApply)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -10, 0, 32)
    row.Position = UDim2.new(0, 5, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
    row.BorderSizePixel = 0
    row.Parent = main
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.58, 0, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = labelText
    lbl.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.36, 0, 0, 24)
    box.Position = UDim2.new(0.62, 0, 0.5, -12)
    box.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.Font = Enum.Font.GothamBold
    box.TextSize = 13
    box.Text = fmt(default)
    box.PlaceholderText = "max / inf"
    box.ClearTextOnFocus = true
    box.BorderSizePixel = 0
    box.Parent = row
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    local current = default
    box.FocusLost:Connect(function()
        local n = parseNum(box.Text)
        if n then
            current = n
            onApply(n)
            box.Text = fmt(n)
            status.Text = (n == math.huge)
                and ("%s MÁXIMO (%d disparos/frame)"):format(labelText, BURST_CAP)
                or ("%s %s por segundo"):format(labelText, fmt(n))
        else
            box.Text = fmt(current)
            status.Text = "Valor inválido. Use número, 1k, 1m, 1e9, max ou inf."
        end
    end)
    return box
end

makeSpeedBox("Veloc. treino /s:", 38, TRAIN_SPEED, function(n)
    TRAIN_SPEED = n
    local i = (n == math.huge) and 0 or (1 / n)
    RATE.punch, RATE.weight, RATE.pushup, RATE.all = i, i, i, i
end)

makeSpeedBox("Veloc. rebirth /s:", 74, REBIRTH_SPEED, function(n)
    REBIRTH_SPEED = n
    RATE.rebirth = (n == math.huge) and 0 or (1 / n)
end)

-- ===== Loop Position (posição + postura) =====
local lockCF, lockAnims, myTracks = nil, {}, {}

local function capturePose()
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return false end
    lockCF = hrp.CFrame
    lockAnims = {}
    local animator = hum:FindFirstChildOfClass("Animator")
    if animator then
        for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
            if tr.Animation and tr.Animation.AnimationId ~= "" then
                table.insert(lockAnims, {id = tr.Animation.AnimationId, t = tr.TimePosition, prio = tr.Priority})
            end
        end
    end
    return true
end

local function clearTracks()
    for _, tr in ipairs(myTracks) do pcall(function() tr:Stop(0) tr:Destroy() end) end
    myTracks = {}
end

local function applyPose(char)
    local hum = char:WaitForChild("Humanoid", 10)
    local hrp = char:WaitForChild("HumanoidRootPart", 10)
    if not (hum and hrp) then return end
    local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5)
    if not animator then return end
    local animate = char:FindFirstChild("Animate")
    if animate then pcall(function() animate.Disabled = true end) end
    hum.AutoRotate = false
    clearTracks()
    for _, a in ipairs(lockAnims) do
        local obj = Instance.new("Animation")
        obj.AnimationId = a.id
        local ok, tr = pcall(function() return animator:LoadAnimation(obj) end)
        if ok and tr then
            pcall(function() tr.Priority = a.prio end)
            tr:Play(0, 1, 0)
            tr.TimePosition = a.t
            tr:AdjustSpeed(0)
            table.insert(myTracks, tr)
        end
    end
end

local function releasePose()
    clearTracks()
    local char = lp.Character
    if char then
        local animate = char:FindFirstChild("Animate")
        if animate then pcall(function() animate.Disabled = false end) end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = true end
    end
end

-- ===== Botões (lista rolável) =====
makeToggle("Auto Punch Fast", "punch")
makeToggle("Auto Weight Fast", "weight")
makeToggle("Auto Flexões", "pushup")
makeToggle("Auto Treinar Tudo", "all")
makeToggle("Auto Max Rebirth", "rebirth")

local loopBtn
loopBtn = makeButton("Loop Position: OFF")
loopBtn.MouseButton1Click:Connect(function()
    if not state.loop then
        if not capturePose() then status.Text = "Personagem não encontrado." return end
        state.loop = true
        applyPose(lp.Character)
    else
        state.loop = false
        releasePose()
    end
    setBtn(loopBtn, "Loop Position", state.loop)
end)

local defaultSpeed = 16
local speedBtn
speedBtn = makeButton("Loop Speed " .. SPEED_VALUE .. ": OFF")
speedBtn.MouseButton1Click:Connect(function()
    state.speed = not state.speed
    local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
    if state.speed then
        if hum and hum.WalkSpeed ~= SPEED_VALUE then defaultSpeed = hum.WalkSpeed end
    elseif hum then
        hum.WalkSpeed = defaultSpeed
    end
    setBtn(speedBtn, "Loop Speed " .. SPEED_VALUE, state.speed)
end)

makeToggle("Anti AFK", "afk")
makeToggle("Anti Kick", "kick")

local recTrainBtn = makeButton("Gravar treino (" .. REC_SECONDS .. "s)")
recTrainBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 190)
local recRebirthBtn = makeButton("Gravar rebirth (" .. REC_SECONDS .. "s)")
recRebirthBtn.BackgroundColor3 = Color3.fromRGB(190, 120, 40)

local function namesOf(list)
    local names = {}
    for _, r in ipairs(list) do
        local ok, n = pcall(function() return r.remote.Name end)
        if ok then table.insert(names, n) end
    end
    return #names > 0 and table.concat(names, ", ") or "nenhum"
end
local function updateStatus()
    status.Text = ("Hook: %s\nTreino: %s\nRebirth: %s"):format(hookMethod, namesOf(recordedTrain), namesOf(recordedRebirth))
end

local function startRecording(target, btn, label, msg)
    if recTarget then return end
    recBuffer, recSeen, recTarget = {}, {}, target
    local startCalls = hookCalls
    btn.Text = "GRAVANDO..."
    status.Text = msg
    -- contador ao vivo
    task.spawn(function()
        while recTarget == target do
            status.Text = ("%s\nCapturado: %d remotes | chamadas: %d"):format(msg, #recBuffer, hookCalls - startCalls)
            task.wait(0.4)
        end
    end)
    task.delay(REC_SECONDS, function()
        if target == "train" then recordedTrain = recBuffer else recordedRebirth = recBuffer end
        local got = #recBuffer
        recTarget, recBuffer = nil, nil
        btn.Text = label
        if got > 0 then
            updateStatus()
        elseif hookMethod == "nenhum" then
            status.Text = "Seu executor não aceitou nenhum hook. Gravação impossível; use só Treinar Tudo (estação/toque)."
        elseif hookCalls - startCalls == 0 then
            status.Text = "Hook ativo (" .. hookMethod .. ") mas 0 chamadas: o jogo não enviou remotes. O treino pode usar toque/ProximityPrompt."
        else
            status.Text = "Houve chamadas, mas só de remotes ignorados (ruído). Me mande o nome dos remotes."
        end
    end)
end
recTrainBtn.MouseButton1Click:Connect(function()
    startRecording("train", recTrainBtn, "Gravar treino (" .. REC_SECONDS .. "s)", "Treine manualmente agora (barra, supino...)")
end)
recRebirthBtn.MouseButton1Click:Connect(function()
    startRecording("rebirth", recRebirthBtn, "Gravar rebirth (" .. REC_SECONDS .. "s)", "Abra RENASCIMENTO, escolha MÁXIMO e confirme.")
end)

-- ===== Hook: grava remotes + anti kick (3 métodos) =====
-- IMPORTANTE: dentro do hook só usa funções string.* (sem ":método") p/ não corromper o namecall
local function isNoise(name)
    local n = string.lower(name)
    for _, w in ipairs(NOISE) do
        if string.find(n, w, 1, true) then return true end
    end
    return false
end

local nameCache = {}
local function classify(name)
    local v = nameCache[name]
    if v ~= nil then return v end
    local n = string.lower(name)
    for key, list in pairs(KEYWORDS) do
        for _, k in ipairs(list) do
            if string.find(n, k, 1, true) then nameCache[name] = key return key end
        end
    end
    nameCache[name] = false
    return false
end

local function handle(self, method, ...)
    if replaying then return end
    if method ~= "FireServer" and method ~= "InvokeServer" then return end
    hookCalls += 1
    local ok, name = pcall(function() return self.Name end)
    if not ok or type(name) ~= "string" then return end
    if recTarget and recBuffer and not recSeen[self] and not isNoise(name) and #recBuffer < 12 then
        recSeen[self] = true
        table.insert(recBuffer, {remote = self, args = {...}})
    end
    local key = classify(name)
    if key then captured[key] = {remote = self, args = {...}} end
end

local function installHooks()
    -- Método 1: hookmetamethod(__namecall)
    if hookmetamethod and getnamecallmethod then
        local ok = pcall(function()
            local old
            old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if state.kick and self == lp and string.lower(method) == "kick" then return end
                handle(self, method, ...)
                if setnamecallmethod then setnamecallmethod(method) end
                return old(self, ...)
            end))
        end)
        if ok then return "hookmetamethod" end
    end

    -- Método 2: hookfunction em FireServer / InvokeServer
    if hookfunction then
        local ok = pcall(function()
            local re = Instance.new("RemoteEvent")
            local rf = Instance.new("RemoteFunction")
            local oldFS, oldIS
            oldFS = hookfunction(re.FireServer, newcclosure(function(self, ...)
                handle(self, "FireServer", ...)
                return oldFS(self, ...)
            end))
            oldIS = hookfunction(rf.InvokeServer, newcclosure(function(self, ...)
                handle(self, "InvokeServer", ...)
                return oldIS(self, ...)
            end))
        end)
        if ok then return "hookfunction" end
    end

    -- Método 3: getrawmetatable + setreadonly
    if getrawmetatable and getnamecallmethod then
        local ok = pcall(function()
            local mt = getrawmetatable(game)
            local old = mt.__namecall
            if setreadonly then setreadonly(mt, false) end
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if state.kick and self == lp and string.lower(method) == "kick" then return end
                handle(self, method, ...)
                if setnamecallmethod then setnamecallmethod(method) end
                return old(self, ...)
            end)
            if setreadonly then setreadonly(mt, true) end
        end)
        if ok then return "getrawmetatable" end
    end
    return "nenhum"
end

hookMethod = installHooks()
status.Text = "Hook: " .. hookMethod .. (hookMethod == "nenhum" and " (gravação indisponível)" or " (OK)")

-- ===== Helpers =====
local function fire(remote, args)
    pcall(function()
        if remote:IsA("RemoteEvent") then remote:FireServer(unpack(args))
        else remote:InvokeServer(unpack(args)) end
    end)
end

local fallback, lastSearch = {}, {}
local function findRemote(key)
    local f = fallback[key]
    if f and f.Parent then return f end
    if lastSearch[key] and os.clock() - lastSearch[key] < 5 then return nil end
    lastSearch[key] = os.clock()
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            if classify(v.Name) == key then fallback[key] = v return v end
        end
    end
end

local function replay(key, times)
    local c = captured[key]
    local remote, args = nil, {}
    if c and c.remote.Parent then remote, args = c.remote, c.args
    else remote = findRemote(key) end
    if not remote then return false end
    replaying = true
    for _ = 1, times do fire(remote, args) end
    replaying = false
    return true
end

local function replayList(list)
    if #list == 0 then return false end
    local fired = false
    replaying = true
    for _, r in ipairs(list) do
        if r.remote.Parent then fire(r.remote, r.args) fired = true end
    end
    replaying = false
    return fired
end

local toolCache = {}
local function getTool(key)
    local t = toolCache[key]
    if t and t.Parent and (t.Parent == lp.Character or t.Parent == lp:FindFirstChild("Backpack")) then return t end
    for _, c in ipairs({lp.Character, lp:FindFirstChild("Backpack")}) do
        if c then
            for _, x in ipairs(c:GetChildren()) do
                if x:IsA("Tool") then
                    local n = x.Name:lower()
                    for _, k in ipairs(TOOL_WORDS[key]) do
                        if n:find(k, 1, true) then toolCache[key] = x return x end
                    end
                end
            end
        end
    end
end

local function equip(key)
    local char = lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local t = getTool(key)
    if hum and t and t.Parent ~= char then pcall(function() hum:EquipTool(t) end) end
    if t and t.Parent == char then pcall(function() t:Activate() end) end
end

local function clickRebirthUI()
    local pg = lp:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, v in ipairs(pg:GetDescendants()) do
        if (v:IsA("TextButton") or v:IsA("ImageButton")) and v.Visible then
            local txt = (v.Name .. " " .. (v:IsA("TextButton") and v.Text or "")):lower()
            if txt:find("rebirth", 1, true) or txt:find("renasc", 1, true) then
                pcall(function()
                    for _, c in ipairs(getconnections(v.MouseButton1Click)) do c:Fire() end
                    for _, c in ipairs(getconnections(v.Activated)) do c:Fire() end
                end)
            end
        end
    end
end

-- ===== Loop principal =====
local acc = {punch = 0, weight = 0, pushup = 0, all = 0, rebirth = 0}
local equipKeys, equipIdx, equipTimer = {}, 1, 0

local function takeShots(key, dt)
    local iv = RATE[key]
    if iv <= 0 then acc[key] = 0 return BURST_CAP end
    acc[key] += dt
    local s = math.floor(acc[key] / iv)
    if s <= 0 then return 0 end
    if s > BURST_CAP then
        s = BURST_CAP
        acc[key] = 0
    else
        acc[key] -= s * iv
    end
    return s
end

RunService.Heartbeat:Connect(function(dt)
    equipTimer += dt
    if equipTimer >= 0.4 then
        equipTimer = 0
        equipKeys = {}
        for _, k in ipairs(ACTIONS) do if state[k] then table.insert(equipKeys, k) end end
        if #equipKeys > 0 then equipIdx = (equipIdx % #equipKeys) + 1 end
    end

    for _, k in ipairs(ACTIONS) do
        if state[k] then
            local shots = takeShots(k, dt)
            if shots > 0 then
                if equipKeys[equipIdx] == k then equip(k) end
                replay(k, shots)
            end
        end
    end

    if state.all then
        local shots = takeShots("all", dt)
        if shots > 0 then
            local char = lp.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then pcall(function() tool:Activate() end) end
            for _ = 1, shots do
                replayList(recordedTrain)
                for _, k in ipairs(ACTIONS) do
                    if captured[k] then replay(k, 1) end
                end
            end
        end
    end

    if state.rebirth then
        local shots = takeShots("rebirth", dt)
        if shots > 0 then
            local fired = false
            for _ = 1, shots do
                if replayList(recordedRebirth) then fired = true else break end
            end
            if not fired then
                for _ = 1, shots do
                    if replay("rebirth", 1) then fired = true else break end
                end
            end
            if not fired then clickRebirthUI() end
        end
    end

    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if state.speed and hum and hrp and not state.loop then
        local current = hum.WalkSpeed
        if current ~= SPEED_VALUE then
            hum.WalkSpeed = SPEED_VALUE
            if hum.MoveDirection.Magnitude > 0 then
                hrp.CFrame = hrp.CFrame + hum.MoveDirection * (SPEED_VALUE - current) * dt
            end
        end
    end

    if state.loop and lockCF and hrp then
        hrp.CFrame = lockCF
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        local animator = hum and hum:FindFirstChildOfClass("Animator")
        if animator and #myTracks > 0 then
            local mine = {}
            for _, tr in ipairs(myTracks) do mine[tr] = true end
            for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
                if not mine[tr] then pcall(function() tr:Stop(0) end) end
            end
        end
    end
end)

lp.CharacterAdded:Connect(function(char)
    if state.loop and lockCF then
        task.wait(0.2)
        applyPose(char)
    end
end)

-- Toque na tela (tap-to-train)
task.spawn(function()
    while task.wait(TAP_INTERVAL) do
        if state.all and TAP_ENABLED then
            local cam = workspace.CurrentCamera
            if cam then
                local v = cam.ViewportSize
                pcall(function() VirtualUser:ClickButton1(Vector2.new(v.X * 0.5, v.Y * 0.6), cam.CFrame) end)
            end
        end
    end
end)

-- ===== Estação mais próxima =====
local stations = {}
local function addStation(v)
    if v:IsA("ProximityPrompt") or v:IsA("ClickDetector") then stations[v] = true end
end
task.spawn(function()
    local n = 0
    for _, v in ipairs(workspace:GetDescendants()) do
        n += 1
        if n % 1500 == 0 then task.wait() end
        addStation(v)
    end
end)
workspace.DescendantAdded:Connect(addStation)
workspace.DescendantRemoving:Connect(function(v) stations[v] = nil end)

local function stationPos(s)
    local par = s.Parent
    if not par then return nil end
    if par:IsA("BasePart") then return par.Position end
    if par:IsA("Attachment") then return par.WorldPosition end
    if par:IsA("Model") then return par:GetPivot().Position end
end
local function stationText(s)
    local par = s.Parent
    local gp = par and par.Parent
    local t = (par and par.Name or "") .. " " .. (gp and gp.Name or "")
    if s:IsA("ProximityPrompt") then t = s.ActionText .. " " .. s.ObjectText .. " " .. t end
    return t:lower()
end
local function hasWord(txt, list)
    for _, w in ipairs(list) do if txt:find(w, 1, true) then return true end end
    return false
end
local function nearestStation(hrp)
    local best, bd
    for s in pairs(stations) do
        if s.Parent and (not s:IsA("ProximityPrompt") or s.Enabled) then
            local pos = stationPos(s)
            if pos then
                local txt = stationText(s)
                if not hasWord(txt, BLACKLIST) and hasWord(txt, STATION_WORDS) then
                    local d = (pos - hrp.Position).Magnitude
                    if not bd or d < bd then best, bd = s, d end
                end
            end
        end
    end
    return best, bd
end

task.spawn(function()
    while task.wait(3) do
        if state.all and not state.loop then
            local char = lp.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and not hum.Sit and #recordedTrain == 0 then
                local s, dist = nearestStation(hrp)
                if s then
                    local pos = stationPos(s)
                    local reach = s:IsA("ProximityPrompt") and math.max((s.MaxActivationDistance or 10) - 3, 3) or 8
                    if dist > reach and dist < 300 then
                        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 3))
                        task.wait(0.25)
                    end
                    if s:IsA("ProximityPrompt") then
                        pcall(function() s.HoldDuration = 0 end)
                        pcall(function() fireproximityprompt(s) end)
                    else
                        pcall(function() fireclickdetector(s) end)
                    end
                end
            end
        end
    end
end)

-- ===== Anti AFK =====
lp.Idled:Connect(function()
    if state.afk then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)
