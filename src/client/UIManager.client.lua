-- UIManager.client.lua  (V4)
-- Full GUI: stats, upgrades, egg shop + hatch cinematic, duel system,
-- leaderboard, god mode flash, event/announce banners, co-op indicator,
-- spin wheel, daily rewards, quests, achievements, free rewards, evolution,
-- ascension button, auto-roll toggle, offline earnings popup

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UIS               = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")
local Upgrades  = require(ReplicatedStorage:WaitForChild("Upgrades"))
local Pets      = require(ReplicatedStorage:WaitForChild("Pets"))
local Eggs      = require(ReplicatedStorage:WaitForChild("Eggs"))
local Quests      = require(ReplicatedStorage:WaitForChild("Quests"))
local Achievements = require(ReplicatedStorage:WaitForChild("Achievements"))
local DailyRewards = require(ReplicatedStorage:WaitForChild("DailyRewards"))
local SpinPrizes   = require(ReplicatedStorage:WaitForChild("SpinPrizes"))

-- ── Util ──────────────────────────────────────────────────────────────────
local function corner(p, r)
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 10); c.Parent=p
end
local function lbl(props, parent)
    local l=Instance.new("TextLabel"); l.BackgroundTransparency=1
    for k,v in pairs(props) do l[k]=v end; l.Parent=parent; return l
end
local function btn(props, parent)
    local b=Instance.new("TextButton"); b.BorderSizePixel=0
    for k,v in pairs(props) do b[k]=v end; b.Parent=parent; return b
end

-- ── Constants ─────────────────────────────────────────────────────────────
local RARITY_COLORS={
    Common    = Color3.fromRGB(190,190,190),
    Rare      = Color3.fromRGB(80,140,255),
    Legendary = Color3.fromRGB(255,170,0),
}
local EGG_COLORS={}
for _, e in ipairs(Eggs) do EGG_COLORS[e.id]=e.color end

-- Pet lookup
local petById={}
for _, p in ipairs(Pets) do petById[p.id]=p end

-- ── Nav rail dimensions (declared early — used before NAV_TABS block) ──────
local NAV_RAIL_W  = 72   -- px, rail width
local NAV_BTN_W   = 56   -- px, pill width inside rail
local NAV_BTN_H   = 72   -- px, pill height (icon + text label)
local NAV_BAR_H   = 72   -- legacy alias
local NAV_PADDING = 8    -- gap between pills

-- ── Root ScreenGui ─────────────────────────────────────────────────────────
local screen=Instance.new("ScreenGui")
screen.Name="SigmaGui"; screen.ResetOnSpawn=false
screen.IgnoreGuiInset=true; screen.Parent=playerGui

-- ── Tap-anywhere infrastructure ───────────────────────────────────────────
local ClickRemote = Remotes:WaitForChild("ClickSigma")
local lastTapPos  = Vector2.new(0.5, 0.72)

-- Expanding ring ripple at tap position
local function spawnTapRipple(pos)
    local ring = Instance.new("Frame")
    ring.Size                 = UDim2.new(0, 20, 0, 20)
    ring.AnchorPoint          = Vector2.new(0.5, 0.5)
    ring.Position             = UDim2.new(pos.X, 0, pos.Y, 0)
    ring.BackgroundTransparency = 1
    ring.BorderSizePixel      = 0
    ring.ZIndex               = 18
    ring.Parent               = screen
    local stroke = Instance.new("UIStroke", ring)
    stroke.Color     = Color3.fromRGB(255, 215, 0)
    stroke.Thickness = 2
    Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
    TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size=UDim2.new(0, 90, 0, 90)}):Play()
    TweenService:Create(stroke, TweenInfo.new(0.4), {Transparency=1}):Play()
    task.delay(0.45, function() ring:Destroy() end)
end

-- Full-screen transparent click catcher (ZIndex=1; all panels are ZIndex 2-8 so they intercept first)
local tapCatcher = Instance.new("TextButton")
tapCatcher.Name                   = "TapCatcher"
tapCatcher.Size                   = UDim2.new(1, 0, 1, 0)
tapCatcher.BackgroundTransparency = 1
tapCatcher.Text                   = ""
tapCatcher.ZIndex                 = 1
tapCatcher.AutoButtonColor        = false
tapCatcher.Parent                 = screen
tapCatcher.MouseButton1Down:Connect(function()
    local mp = UIS:GetMouseLocation()
    local vp = workspace.CurrentCamera.ViewportSize
    lastTapPos = Vector2.new(mp.X / vp.X, mp.Y / vp.Y)
    ClickRemote:FireServer()
    spawnTapRipple(lastTapPos)
end)
tapCatcher.TouchTap:Connect(function(tps)
    if tps and #tps > 0 then
        local vp = workspace.CurrentCamera.ViewportSize
        lastTapPos = Vector2.new(tps[1].X / vp.X, tps[1].Y / vp.Y)
    end
    ClickRemote:FireServer()
    spawnTapRipple(lastTapPos)
end)

-- Onboarding hint — fades on first tap or after 5 seconds
local _hintDone = false
local tapHint = Instance.new("Frame")
tapHint.Size                   = UDim2.new(0, 240, 0, 52)
tapHint.AnchorPoint            = Vector2.new(0.5, 1)
tapHint.Position               = UDim2.new(0.5, 0, 1, -90)
tapHint.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
tapHint.BackgroundTransparency = 0.35
tapHint.ZIndex                 = 12
tapHint.Parent                 = screen
corner(tapHint, 26)
local tapHintLbl = lbl({Size=UDim2.new(1,0,1,0), Text="👆  Tap anywhere!",
    TextColor3=Color3.fromRGB(255,255,255), TextScaled=true,
    Font=Enum.Font.GothamBold, ZIndex=13}, tapHint)
local function dismissHint()
    if _hintDone then return end; _hintDone = true
    TweenService:Create(tapHint,    TweenInfo.new(0.5), {BackgroundTransparency=1}):Play()
    TweenService:Create(tapHintLbl, TweenInfo.new(0.5), {TextTransparency=1}):Play()
    task.delay(0.6, function() if tapHint and tapHint.Parent then tapHint:Destroy() end end)
end
tapCatcher.MouseButton1Down:Connect(dismissHint)
tapCatcher.TouchTap:Connect(function() dismissHint() end)
task.delay(5, dismissHint)

-- ── TOP RIGHT: Rizz counter ───────────────────────────────────────────────
local rizzFrame=Instance.new("Frame")
rizzFrame.Size=UDim2.new(0,180,0,46); rizzFrame.Position=UDim2.new(1,-190-NAV_RAIL_W,0,12)
rizzFrame.BackgroundColor3=Color3.fromRGB(255,255,255); rizzFrame.BackgroundTransparency=0.82
rizzFrame.BorderSizePixel=0; rizzFrame.Parent=screen; corner(rizzFrame)
do local s=Instance.new("UIStroke",rizzFrame); s.Color=Color3.fromRGB(180,80,255); s.Transparency=0.35; s.Thickness=1 end
local rizzLabel=lbl({Name="RizzLabel",Size=UDim2.new(1,-8,1,0),Position=UDim2.new(0,4,0,0),
    Text="💎  0 Rizz",TextColor3=Color3.fromRGB(230,180,255),TextScaled=true,
    Font=Enum.Font.GothamBold},rizzFrame)

-- ── TOP CENTER: Sigma + pet income ───────────────────────────────────────
local sigmaFrame=Instance.new("Frame")
sigmaFrame.Size=UDim2.new(0,320,0,76); sigmaFrame.Position=UDim2.new(0.5,-160,0,12)
sigmaFrame.BackgroundColor3=Color3.fromRGB(255,255,255); sigmaFrame.BackgroundTransparency=0.82
sigmaFrame.BorderSizePixel=0; sigmaFrame.Parent=screen; corner(sigmaFrame)
do local s=Instance.new("UIStroke",sigmaFrame); s.Color=Color3.fromRGB(200,200,255); s.Transparency=0.45; s.Thickness=1 end
local sigmaLabel=lbl({Name="SigmaLabel",Size=UDim2.new(1,0,0.45,0),
    Text="😎  0 σ",TextColor3=Color3.fromRGB(255,215,0),TextScaled=true,Font=Enum.Font.GothamBold},sigmaFrame)
local petIncomeLabel=lbl({Name="PetLabel",Size=UDim2.new(1,0,0.28,0),Position=UDim2.new(0,0,0.45,0),
    Text="🐾 0 σ/sec",TextColor3=Color3.fromRGB(110,230,110),TextScaled=true,Font=Enum.Font.Gotham},sigmaFrame)
local multLabel=lbl({Name="MultLabel",Size=UDim2.new(1,0,0.27,0),Position=UDim2.new(0,0,0.73,0),
    Text="x1 per click",TextColor3=Color3.fromRGB(200,200,255),TextScaled=true,Font=Enum.Font.Gotham},sigmaFrame)

-- Spin boost indicator
local spinBoostLabel=lbl({Name="SpinBoostLabel",Size=UDim2.new(0,180,0,22),
    Position=UDim2.new(1,-190-NAV_RAIL_W,0,62),
    Text="",TextColor3=Color3.fromRGB(255,100,255),TextScaled=true,
    Font=Enum.Font.GothamBold,Visible=false},screen)

-- ── Rank + progress ───────────────────────────────────────────────────────
local rankFrame=Instance.new("Frame")
rankFrame.Size=UDim2.new(0,320,0,42); rankFrame.Position=UDim2.new(0.5,-160,0,92)
rankFrame.BackgroundColor3=Color3.fromRGB(255,255,255); rankFrame.BackgroundTransparency=0.82
rankFrame.BorderSizePixel=0; rankFrame.Parent=screen; corner(rankFrame)
do local s=Instance.new("UIStroke",rankFrame); s.Color=Color3.fromRGB(200,200,255); s.Transparency=0.45; s.Thickness=1 end
local rankLabel=lbl({Name="RankLabel",Size=UDim2.new(1,0,0.6,0),
    Text="🤡  NPC",TextColor3=Color3.fromRGB(220,220,220),TextScaled=true,Font=Enum.Font.GothamBold},rankFrame)
local progBg=Instance.new("Frame")
progBg.Size=UDim2.new(1,-16,0,6); progBg.Position=UDim2.new(0,8,1,-10)
progBg.BackgroundColor3=Color3.fromRGB(50,50,50); progBg.BorderSizePixel=0; progBg.Parent=rankFrame
corner(progBg,3)
local progBar=Instance.new("Frame")
progBar.Size=UDim2.new(0,0,1,0); progBar.BackgroundColor3=Color3.fromRGB(80,200,255)
progBar.BorderSizePixel=0; progBar.Parent=progBg; corner(progBar,3)

-- ── PRESTIGE BUTTON ───────────────────────────────────────────────────────
local prestigeBtn=btn({Name="PrestigeBtn",Size=UDim2.new(0,240,0,48),
    AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,152),
    BackgroundColor3=Color3.fromRGB(120,0,180),Visible=false,
    Text="🌌 PRESTIGE #1",TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,
    Font=Enum.Font.GothamBold},screen)
corner(prestigeBtn)

-- ── ASCENSION BUTTON ──────────────────────────────────────────────────────
local ascendBtn=btn({Name="AscendBtn",Size=UDim2.new(0,240,0,48),
    AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,206),
    BackgroundColor3=Color3.fromRGB(180,100,0),Visible=false,
    Text="✨ ASCEND (P5 TRUE RESET)",TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,
    Font=Enum.Font.GothamBold},screen)
corner(ascendBtn)

-- ── Co-op label ───────────────────────────────────────────────────────────
local coopLabel=lbl({Name="CoopLabel",Size=UDim2.new(0,240,0,32),
    Position=UDim2.new(0,10,0,200),Text="",TextColor3=Color3.fromRGB(80,255,160),
    TextScaled=true,Font=Enum.Font.GothamBold,Visible=false},screen)

-- ── God Mode Flash ────────────────────────────────────────────────────────
local godFlash=Instance.new("Frame")
godFlash.Size=UDim2.new(1,0,1,0); godFlash.BackgroundColor3=Color3.fromRGB(255,215,0)
godFlash.BackgroundTransparency=1; godFlash.ZIndex=20; godFlash.Parent=screen
local godLabel=lbl({Name="GodLabel",Size=UDim2.new(1,0,0.12,0),Position=UDim2.new(0,0,0.44,0),
    Text="⚡ SIGMA GOD MODE ⚡",TextColor3=Color3.fromRGB(255,80,0),TextScaled=true,
    Font=Enum.Font.GothamBold,Visible=false,ZIndex=21},screen)

-- ── Event banner ─────────────────────────────────────────────────────────
local eventBanner=lbl({Name="EventBanner",Size=UDim2.new(1,0,0,52),
    Position=UDim2.new(0,0,0,0),Text="",BackgroundTransparency=0.3,
    BackgroundColor3=Color3.fromRGB(20,0,60),TextColor3=Color3.fromRGB(255,215,0),
    TextScaled=true,Font=Enum.Font.GothamBold,Visible=false},screen)

-- ── Announce banner ───────────────────────────────────────────────────────
local annQueue={}; local annRunning=false
local annBanner=lbl({Name="AnnBanner",Size=UDim2.new(0.6,0,0,44),
    AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,4),
    BackgroundColor3=Color3.fromRGB(30,0,60),BackgroundTransparency=0.1,
    TextColor3=Color3.fromRGB(255,215,0),TextScaled=true,Font=Enum.Font.GothamBold,
    Visible=false,ZIndex=15},screen); corner(annBanner)
local function showAnn(msg)
    table.insert(annQueue,msg)
    if annRunning then return end
    annRunning=true
    task.spawn(function()
        while #annQueue>0 do
            local m=table.remove(annQueue,1)
            annBanner.Text=m; annBanner.Visible=true
            task.wait(3); annBanner.Visible=false; task.wait(0.2)
        end
        annRunning=false
    end)
end

-- ── NAV BAR (modern capsule style) ───────────────────────────────────────
-- Tab definition: name, icon emoji, accent colour (used for selected state)
local NAV_TABS = {
    { id="Upgrades", icon="⚡", label="Boost",   accent=Color3.fromRGB(100, 80, 255)  },
    { id="Pets",     icon="🐾", label="Pets",    accent=Color3.fromRGB(60, 200, 100)  },
    { id="Shop",     icon="🥚", label="Shop",    accent=Color3.fromRGB(255, 160, 30)  },
    { id="Duels",    icon="⚔️",  label="Duel",    accent=Color3.fromRGB(255, 60, 80)   },
    { id="LB",       icon="🏆", label="Rank",    accent=Color3.fromRGB(255, 215, 0)   },
    { id="Spin",     icon="🎡", label="Spin",    accent=Color3.fromRGB(220, 60, 255)  },
    { id="Daily",    icon="📅", label="Daily",   accent=Color3.fromRGB(40, 180, 255)  },
    { id="Quests",   icon="📋", label="Quests",  accent=Color3.fromRGB(60, 220, 140)  },
    { id="Achieve",  icon="🏅", label="Awards",  accent=Color3.fromRGB(255, 140, 30)  },
    { id="Free",     icon="🎁", label="Free",    accent=Color3.fromRGB(40, 220, 200)  },
}

-- Nav rail dimensions declared at top of file (before ScreenGui creation).

-- ── Bar backing surface ───────────────────────────────────────────────────
local navBacking = Instance.new("Frame")
navBacking.Name             = "NavBacking"
navBacking.Size             = UDim2.new(0, NAV_RAIL_W, 1, 0)
navBacking.Position         = UDim2.new(1, -NAV_RAIL_W, 0, 0)
navBacking.BackgroundColor3 = Color3.fromRGB(10, 5, 25)
navBacking.BackgroundTransparency = 0.25
navBacking.BorderSizePixel  = 0
navBacking.ZIndex           = 5
navBacking.Parent           = screen
do
    local gs = Instance.new("UIStroke", navBacking)
    gs.Color = Color3.fromRGB(130, 70, 220); gs.Transparency = 0.5; gs.Thickness = 1
    gs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    local gg = Instance.new("UIGradient", navBacking)
    gg.Rotation = 90
    gg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 40, 120)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 5, 25)),
    })
    gg.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.35),
    })
end

-- Left edge separator line (for vertical rail)
local navSep = Instance.new("Frame")
navSep.Size             = UDim2.new(0, 1, 1, 0)
navSep.Position         = UDim2.new(0, 0, 0, 0)
navSep.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
navSep.BorderSizePixel  = 0
navSep.ZIndex           = 6
navSep.Parent           = navBacking

-- Scrolling pill row inside the backing
local navBar = Instance.new("ScrollingFrame")
navBar.Name                  = "NavBar"
navBar.Size                  = UDim2.new(1, -NAV_PADDING, 1, -NAV_PADDING)
navBar.Position               = UDim2.new(0, NAV_PADDING // 2, 0, NAV_PADDING // 2)
navBar.BackgroundTransparency = 1
navBar.BorderSizePixel        = 0
navBar.ScrollBarThickness     = 0
navBar.ScrollingDirection     = Enum.ScrollingDirection.Y
navBar.CanvasSize             = UDim2.new(0, 0, 0, #NAV_TABS * (NAV_BTN_H + NAV_PADDING))
navBar.ZIndex                 = 6
navBar.Parent                 = navBacking
navBar.AutomaticCanvasSize    = Enum.AutomaticSize.None

local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection       = Enum.FillDirection.Vertical
navLayout.SortOrder           = Enum.SortOrder.LayoutOrder
navLayout.Padding             = UDim.new(0, NAV_PADDING)
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navLayout.Parent              = navBar

-- ── PANELS container ──────────────────────────────────────────────────────
local panelHost = Instance.new("Frame")
panelHost.Name                  = "PanelHost"
panelHost.Size                  = UDim2.new(1, -NAV_RAIL_W, 1, 0)
panelHost.Position              = UDim2.new(0, 0, 0, 0)
panelHost.BackgroundTransparency = 1
panelHost.ClipsDescendants      = true
panelHost.Active                = false   -- Bug 1 fix: pass clicks through to tapCatcher
panelHost.ZIndex                = 2
panelHost.Parent                = screen

local activePanel    = nil
local activePanelId  = nil
local navBtns        = {}   -- id → { pill, iconLbl, textLbl, accentBar }

-- ── Helper: tween a property ──────────────────────────────────────────────
local function tw(inst, props, t)
    TweenService:Create(inst, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play()
end

-- ── showPanel ─────────────────────────────────────────────────────────────
local function showPanel(id)
    -- Hide old panel
    if activePanel then activePanel.Visible = false end
    local p = panelHost:FindFirstChild(id)
    if p then p.Visible = true; activePanel = p end
    -- Deselect old, select new
    if activePanelId and navBtns[activePanelId] then
        local old     = navBtns[activePanelId]
        local oldAcc  = old.accent
        tw(old.pill,      { BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.88 })
        tw(old.accentBar, { BackgroundTransparency = 1 })
        tw(old.textLbl,   { TextColor3 = Color3.fromRGB(160, 160, 180) })
        tw(old.iconLbl,   { TextTransparency = 0.3 })
        if old.stroke then tw(old.stroke, { Transparency = 0.55 }) end
    end
    activePanelId = id
    if navBtns[id] then
        local cur    = navBtns[id]
        local accent = cur.accent
        tw(cur.pill,      { BackgroundColor3 = accent, BackgroundTransparency = 0.55 })
        tw(cur.accentBar, { BackgroundColor3 = accent, BackgroundTransparency = 0 })
        tw(cur.textLbl,   { TextColor3 = Color3.fromRGB(255, 255, 255) })
        tw(cur.iconLbl,   { TextTransparency = 0 })
        if cur.stroke then
            cur.stroke.Color = accent
            tw(cur.stroke, { Transparency = 0.1 })
        end
    end
end

local panels = {}
local function makePanel(name)
    local f = Instance.new("ScrollingFrame")
    f.Name                  = name
    f.Size                  = UDim2.new(1, 0, 1, 0)
    f.Position              = UDim2.new(0, 0, 0, 0)
    f.BackgroundColor3      = Color3.fromRGB(14, 14, 22)
    f.BorderSizePixel       = 0
    f.ScrollBarThickness    = 4
    f.ScrollBarImageColor3  = Color3.fromRGB(80, 80, 120)
    f.CanvasSize            = UDim2.new(0, 0, 0, 0)
    f.Visible               = false
    -- NOTE: Active NOT set to false here — buttons inside panels must be clickable
    f.ZIndex                = 3
    f.Parent                = panelHost
    panels[name] = f
    return f
end

-- ── Build each nav capsule ─────────────────────────────────────────────────
for i, tab in ipairs(NAV_TABS) do
    -- Outer pill
    local pill = Instance.new("TextButton")
    pill.Name                   = "NavPill_"..tab.id
    pill.Size                   = UDim2.new(0, NAV_BTN_W, 0, NAV_BTN_H)
    pill.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
    pill.BackgroundTransparency = 0.88
    pill.BorderSizePixel        = 0
    pill.Text                   = ""
    pill.LayoutOrder            = i
    pill.ZIndex                 = 7
    pill.Parent                 = navBar
    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(0, 24)
    pillCorner.Parent       = pill

    -- Subtle border stroke (hidden when unselected)
    local pillStroke = Instance.new("UIStroke")
    pillStroke.Color       = Color3.fromRGB(200, 180, 255)
    pillStroke.Thickness   = 1.5
    pillStroke.Transparency = 0.55
    pillStroke.Parent      = pill

    -- Left accent bar (hidden when unselected)
    local accentBar = Instance.new("Frame")
    accentBar.Size                  = UDim2.new(0, 3, 0.6, 0)
    accentBar.AnchorPoint           = Vector2.new(0, 0.5)
    accentBar.Position              = UDim2.new(0, 1, 0.5, 0)
    accentBar.BackgroundColor3      = tab.accent
    accentBar.BackgroundTransparency = 1
    accentBar.BorderSizePixel       = 0
    accentBar.ZIndex                = 8
    accentBar.Parent                = pill
    Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)

    -- Icon label (fills pill — icon-first for accessibility)
    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size                 = UDim2.new(1, 0, 0.56, 0)
    iconLbl.Position             = UDim2.new(0, 0, 0.06, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text                 = tab.icon
    iconLbl.TextScaled           = true
    iconLbl.Font                 = Enum.Font.GothamBold
    iconLbl.TextColor3           = Color3.fromRGB(255, 255, 255)
    iconLbl.TextTransparency     = 0.3
    iconLbl.ZIndex               = 8
    iconLbl.Parent               = pill

    -- Text label (hidden on vertical rail — icons only)
    local textLbl = Instance.new("TextLabel")
    textLbl.Size                 = UDim2.new(1, -4, 0.28, 0)
    textLbl.Position             = UDim2.new(0, 2, 0.66, 0)
    textLbl.BackgroundTransparency = 1
    textLbl.Text                 = tab.label
    textLbl.TextScaled           = true
    textLbl.Font                 = Enum.Font.Gotham
    textLbl.TextColor3           = Color3.fromRGB(160, 160, 180)
    textLbl.ZIndex               = 8
    textLbl.Visible              = true
    textLbl.Parent               = pill

    -- Store refs
    navBtns[tab.id] = {
        pill      = pill,
        iconLbl   = iconLbl,
        textLbl   = textLbl,
        accentBar = accentBar,
        stroke    = pillStroke,
        accent    = tab.accent,
    }

    -- Press animation + panel switch
    local tabId = tab.id
    pill.MouseButton1Down:Connect(function()
        tw(pill, { Size = UDim2.new(0, NAV_BTN_W - 6, 0, NAV_BTN_H - 6) }, 0.08)
    end)
    pill.MouseButton1Up:Connect(function()
        tw(pill, { Size = UDim2.new(0, NAV_BTN_W, 0, NAV_BTN_H) }, 0.12)
        showPanel(tabId)
    end)
    -- Touch support (fires after Up on mobile too, but MouseButton1Up covers it)
    pill.TouchTap:Connect(function()
        showPanel(tabId)
    end)
end

-- ── PANEL: Upgrades ───────────────────────────────────────────────────────
local upgPanel=makePanel("Upgrades")
upgPanel.CanvasSize=UDim2.new(0,0,0,#Upgrades*80+20)
local upgLayout=Instance.new("UIListLayout")
upgLayout.Padding=UDim.new(0,8); upgLayout.Parent=upgPanel
Instance.new("UIPadding",upgPanel).PaddingTop=UDim.new(0,8)
local upgradeButtons={}
for _, u in ipairs(Upgrades) do
    local b=btn({Size=UDim2.new(1,-20,0,66),
        BackgroundColor3=Color3.fromRGB(28,28,48),
        Text="["..u.icon.."]  "..u.name.."\n"..u.description.."   Cost: "..u.cost.."σ",
        TextColor3=Color3.fromRGB(200,200,255),TextScaled=true,Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left},upgPanel)
    Instance.new("UIPadding",b).PaddingLeft=UDim.new(0,10); corner(b)
    upgradeButtons[u.id]=b
    local uid=u.id
    b.MouseButton1Click:Connect(function()
        Remotes:WaitForChild("BuyUpgrade"):FireServer(uid)
    end)
end

-- ── PANEL: Pets ────────────────────────────────────────────────────────────
local petPanel=makePanel("Pets")
local petPanelLayout=Instance.new("UIListLayout")
petPanelLayout.Padding=UDim.new(0,6); petPanelLayout.Parent=petPanel
Instance.new("UIPadding",petPanel).PaddingTop=UDim.new(0,8)

local function rebuildMyPets(ownedPets, equippedPets, evolvedPets)
    for _, c in ipairs(petPanel:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
    end
    local equipped={}
    for _, id in ipairs(equippedPets or {}) do equipped[tostring(id)]=true end
    local evolved=evolvedPets or {}
    for _, pet in ipairs(Pets) do
        local key=tostring(pet.id)
        local count=ownedPets and (ownedPets[key] or 0) or 0
        local isEvo=evolved[key]
        local isEquip=equipped[key]
        local col=RARITY_COLORS[pet.rarity] or Color3.fromRGB(200,200,200)
        local row=Instance.new("Frame")
        row.Size=UDim2.new(1,-16,0,66); row.BackgroundColor3=col
        row.BackgroundTransparency=0.7; row.BorderSizePixel=0; row.Parent=petPanel
        corner(row)
        local emo=isEvo and (pet.evolvedEmoji or "🌟") or pet.emoji
        local name=isEvo and (pet.evolvedName or pet.name.." ✨") or pet.name
        lbl({Size=UDim2.new(0.55,0,1,0),
            Text=emo.."  "..name.."  x"..count,TextColor3=Color3.fromRGB(255,255,255),
            TextScaled=true,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},row)
        -- Equip/Unequip
        local ebtn=btn({Size=UDim2.new(0.2,0,0.7,0),AnchorPoint=Vector2.new(1,0.5),
            Position=UDim2.new(1,-8,0.5,0),
            BackgroundColor3=isEquip and Color3.fromRGB(0,180,80) or Color3.fromRGB(60,60,80),
            Text=isEquip and "📌" or "Equip",TextColor3=Color3.fromRGB(255,255,255),
            TextScaled=true,Font=Enum.Font.GothamBold},row); corner(ebtn)
        local pid=pet.id
        ebtn.MouseButton1Click:Connect(function()
            Remotes:WaitForChild("EquipPet"):FireServer(pid)
        end)
        -- Evolve button (requires 3 copies, not yet evolved)
        if count >= 3 and not isEvo then
            local evbtn=btn({Size=UDim2.new(0.21,0,0.7,0),AnchorPoint=Vector2.new(1,0.5),
                Position=UDim2.new(0.78,0,0.5,0),
                BackgroundColor3=Color3.fromRGB(180,80,0),
                Text="🌟 Evolve",TextColor3=Color3.fromRGB(255,255,255),
                TextScaled=true,Font=Enum.Font.GothamBold},row); corner(evbtn)
            evbtn.MouseButton1Click:Connect(function()
                Remotes:WaitForChild("EvolvePet"):FireServer(pid)
            end)
        end
    end
    petPanel.CanvasSize=UDim2.new(0,0,0,#Pets*74+20)
end

-- ── PANEL: Shop (Egg Hatching) ────────────────────────────────────────────
local shopPanel=makePanel("Shop")
local shopLayout=Instance.new("UIListLayout")
shopLayout.Padding=UDim.new(0,8); shopLayout.Parent=shopPanel
Instance.new("UIPadding",shopPanel).PaddingTop=UDim.new(0,8)
shopPanel.CanvasSize=UDim2.new(0,0,0,#Eggs*90+20)

local autoRollActive={}   -- eggId → bool

for _, egg in ipairs(Eggs) do
    local eggRow=Instance.new("Frame")
    eggRow.Size=UDim2.new(1,-16,0,80); eggRow.BackgroundColor3=egg.color
    eggRow.BackgroundTransparency=0.6; eggRow.BorderSizePixel=0; eggRow.Parent=shopPanel
    corner(eggRow); local eid=egg.id
    lbl({Size=UDim2.new(0.5,0,1,0),Position=UDim2.new(0,8,0,0),
        Text=egg.emoji.."  "..egg.name.."\nCost: "..egg.cost.."💎",
        TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left},eggRow)
    -- Hatch button
    local hbtn=btn({Size=UDim2.new(0.2,0,0.6,0),AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-8,0.5,0),
        BackgroundColor3=Color3.fromRGB(60,120,200),
        Text="🥚 Hatch",TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,
        Font=Enum.Font.GothamBold},eggRow); corner(hbtn)
    hbtn.MouseButton1Click:Connect(function()
        Remotes:WaitForChild("HatchEgg"):FireServer(eid)
    end)
    -- Reroll button
    local rbtn=btn({Size=UDim2.new(0.2,0,0.6,0),AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(0.77,0,0.5,0),
        BackgroundColor3=Color3.fromRGB(140,80,0),
        Text="🔄 Reroll",TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,
        Font=Enum.Font.GothamBold},eggRow); corner(rbtn)
    rbtn.MouseButton1Click:Connect(function()
        Remotes:WaitForChild("RerollEgg"):FireServer(eid)
    end)
    -- Auto-roll toggle
    local arbtn=btn({Size=UDim2.new(0.2,0,0.6,0),AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(0.53,0,0.5,0),
        BackgroundColor3=Color3.fromRGB(40,80,40),
        Text="▶ Auto",TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,
        Font=Enum.Font.GothamBold},eggRow); corner(arbtn)
    arbtn.MouseButton1Click:Connect(function()
        Remotes:WaitForChild("AutoRollToggle"):FireServer(eid)
    end)
    -- Store ref for status updates
    eggRow:SetAttribute("EggId", eid)
    eggRow:SetAttribute("AutoBtnRef", arbtn.Name)
end

-- ── PANEL: Duels ────────────────────────────────────────────────────────────
local duelPanel=makePanel("Duels")
duelPanel.CanvasSize=UDim2.new(0,0,0,420)
local dpLayout=Instance.new("UIListLayout")
dpLayout.Padding=UDim.new(0,8); dpLayout.Parent=duelPanel
Instance.new("UIPadding",duelPanel).PaddingTop=UDim.new(0,10)
lbl({Size=UDim2.new(1,-16,0,34),Text="⚔️  Sigma Duels",
    TextColor3=Color3.fromRGB(255,80,80),TextScaled=true,Font=Enum.Font.GothamBold},duelPanel)
local challengeInput=Instance.new("TextBox")
challengeInput.Size=UDim2.new(1,-16,0,40); challengeInput.PlaceholderText="Enter player name…"
challengeInput.BackgroundColor3=Color3.fromRGB(30,30,30); challengeInput.TextColor3=Color3.fromRGB(255,255,255)
challengeInput.TextScaled=true; challengeInput.Font=Enum.Font.Gotham; challengeInput.Parent=duelPanel; corner(challengeInput)
local challengeBtn=btn({Size=UDim2.new(1,-16,0,44),BackgroundColor3=Color3.fromRGB(180,20,20),
    Text="⚔️ Challenge",TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.GothamBold},duelPanel)
corner(challengeBtn)
challengeBtn.MouseButton1Click:Connect(function()
    local name=challengeInput.Text ; challengeInput.Text=""
    if name~="" then Remotes:WaitForChild("DuelChallenge"):FireServer(name) end
end)
local duelStatus=lbl({Size=UDim2.new(1,-16,0,60),Text="",
    TextColor3=Color3.fromRGB(255,215,0),TextScaled=true,TextWrapped=true,Font=Enum.Font.Gotham},duelPanel)
local duelClickBtn=btn({Size=UDim2.new(1,-16,0,80),BackgroundColor3=Color3.fromRGB(200,100,0),
    Text="👊 CLICK!",TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.GothamBold,Visible=false},duelPanel)
corner(duelClickBtn)
duelClickBtn.MouseButton1Click:Connect(function()
    Remotes:WaitForChild("DuelClick"):FireServer()
end)

-- ── PANEL: Leaderboard ────────────────────────────────────────────────────
local lbPanel=makePanel("LB")
lbPanel.CanvasSize=UDim2.new(0,0,0,340)
local lbLayout=Instance.new("UIListLayout"); lbLayout.Padding=UDim.new(0,6); lbLayout.Parent=lbPanel
Instance.new("UIPadding",lbPanel).PaddingTop=UDim.new(0,8)
lbl({Size=UDim2.new(1,-16,0,36),Text="🏆  Leaderboard",
    TextColor3=Color3.fromRGB(255,215,0),TextScaled=true,Font=Enum.Font.GothamBold},lbPanel)
local boardRows={}
for i=1,5 do
    local r=lbl({Size=UDim2.new(1,-16,0,50),Text="",
        BackgroundColor3=Color3.fromRGB(30,30,30),BackgroundTransparency=0.3,
        TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.Gotham},lbPanel)
    corner(r); table.insert(boardRows,r)
end

-- ── PANEL: Spin Wheel ────────────────────────────────────────────────────
local spinPanel=makePanel("Spin")
spinPanel.CanvasSize=UDim2.new(0,0,0,700)
Instance.new("UIPadding",spinPanel).PaddingTop=UDim.new(0,10)

lbl({Size=UDim2.new(1,-16,0,40),Position=UDim2.new(0,8,0,10),
    Text="🎡  Rizz Spin Wheel",TextColor3=Color3.fromRGB(255,100,255),
    TextScaled=true,Font=Enum.Font.GothamBold,Parent=spinPanel})

-- Visual wheel (static colored segments label list)
local wheelDisplay=Instance.new("Frame")
wheelDisplay.Size=UDim2.new(1,-32,0,260); wheelDisplay.Position=UDim2.new(0,16,0,58)
wheelDisplay.BackgroundColor3=Color3.fromRGB(30,20,50); wheelDisplay.BorderSizePixel=0
wheelDisplay.Parent=spinPanel; corner(wheelDisplay,18)
local segColors={
    Color3.fromRGB(200,50,50),Color3.fromRGB(50,150,200),
    Color3.fromRGB(200,120,0),Color3.fromRGB(50,180,50),
    Color3.fromRGB(180,50,200),Color3.fromRGB(50,200,200),
    Color3.fromRGB(200,200,50),Color3.fromRGB(200,100,100),
}
local segLayout=Instance.new("UIGridLayout"); segLayout.CellSize=UDim2.new(0.5,-4,0,58)
segLayout.CellPaddingH=UDim.new(0,4); segLayout.CellPaddingV=UDim.new(0,4)
segLayout.SortOrder=Enum.SortOrder.LayoutOrder; segLayout.Parent=wheelDisplay
for i, sp in ipairs(SpinPrizes) do
    local sLbl=lbl({Size=UDim2.new(0,0,0,0),LayoutOrder=i,
        BackgroundColor3=segColors[i],BackgroundTransparency=0,
        Text=sp.emoji.."  "..sp.label,TextColor3=Color3.fromRGB(255,255,255),
        TextScaled=true,Font=Enum.Font.GothamBold},wheelDisplay)
    Instance.new("UICorner",sLbl).CornerRadius=UDim.new(0,8)
end

local spinFreeBtn=btn({Size=UDim2.new(0.45,0,0,52),Position=UDim2.new(0.03,0,0,328),
    BackgroundColor3=Color3.fromRGB(60,0,120),
    Text="🆓 Free Spin",TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,
    Font=Enum.Font.GothamBold,Parent=spinPanel}); corner(spinFreeBtn)
local spinPaidBtn=btn({Size=UDim2.new(0.45,0,0,52),Position=UDim2.new(0.52,0,0,328),
    BackgroundColor3=Color3.fromRGB(120,0,60),
    Text="💎 5 Rizz Spin",TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,
    Font=Enum.Font.GothamBold,Parent=spinPanel}); corner(spinPaidBtn)
local spinCooldownLbl=lbl({Size=UDim2.new(1,-16,0,32),Position=UDim2.new(0,8,0,386),
    Text="Free spin ready!",TextColor3=Color3.fromRGB(180,180,255),TextScaled=true,
    Font=Enum.Font.Gotham,Parent=spinPanel})
local spinResultLbl=lbl({Size=UDim2.new(1,-16,0,48),Position=UDim2.new(0,8,0,424),
    Text="",TextColor3=Color3.fromRGB(255,215,0),TextScaled=true,
    Font=Enum.Font.GothamBold,Parent=spinPanel})

spinFreeBtn.MouseButton1Click:Connect(function()
    Remotes:WaitForChild("SpinWheel"):FireServer(false)
end)
spinPaidBtn.MouseButton1Click:Connect(function()
    Remotes:WaitForChild("SpinWheel"):FireServer(true)
end)

-- ── PANEL: Daily Rewards ──────────────────────────────────────────────────
local dailyPanel=makePanel("Daily")
dailyPanel.CanvasSize=UDim2.new(0,0,0,560)
Instance.new("UIPadding",dailyPanel).PaddingTop=UDim.new(0,10)
lbl({Size=UDim2.new(1,-16,0,40),Position=UDim2.new(0,8,0,10),
    Text="📅  Daily Rewards",TextColor3=Color3.fromRGB(80,200,255),
    TextScaled=true,Font=Enum.Font.GothamBold,Parent=dailyPanel})
local dailyStrLbl=lbl({Size=UDim2.new(1,-16,0,32),Position=UDim2.new(0,8,0,56),
    Text="Streak: 0 days",TextColor3=Color3.fromRGB(255,215,0),
    TextScaled=true,Font=Enum.Font.Gotham,Parent=dailyPanel})
local dailyGrid=Instance.new("Frame")
dailyGrid.Size=UDim2.new(1,-16,0,340); dailyGrid.Position=UDim2.new(0,8,0,94)
dailyGrid.BackgroundTransparency=1; dailyGrid.Parent=dailyPanel
local dGridLayout=Instance.new("UIGridLayout"); dGridLayout.CellSize=UDim2.new(0,0,0,78)
-- We'll set cell size dynamically; use a list instead
dGridLayout:Destroy()
local dailyDayFrames={}
for i, dr in ipairs(DailyRewards) do
    local df=Instance.new("Frame")
    df.Size=UDim2.new(0,0,0,0); df.BackgroundTransparency=1; df.Parent=dailyGrid
    -- We'll absolutely position them in a 4-col grid
    local col=((i-1) % 4); local row=math.floor((i-1)/4)
    df.Position=UDim2.new(col/4,4,row/2,4)
    df.Size=UDim2.new(0.25,-8,0,74)
    df.BackgroundColor3=Color3.fromRGB(25,40,60); df.BorderSizePixel=0; corner(df,8)
    lbl({Size=UDim2.new(1,0,0.5,0),Text="Day "..i.."  "..dr.emoji,
        TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.GothamBold},df)
    lbl({Size=UDim2.new(1,0,0.5,0),Position=UDim2.new(0,0,0.5,0),
        Text=dr.label,TextColor3=Color3.fromRGB(180,220,255),TextScaled=true,Font=Enum.Font.Gotham},df)
    table.insert(dailyDayFrames, df)
end
local claimDailyBtn=btn({Size=UDim2.new(0.6,0,0,52),
    AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,448),
    BackgroundColor3=Color3.fromRGB(0,120,200),
    Text="📅 Claim Daily",TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,
    Font=Enum.Font.GothamBold,Parent=dailyPanel}); corner(claimDailyBtn)
local dailyCoolLbl=lbl({Size=UDim2.new(1,-16,0,32),Position=UDim2.new(0,8,0,506),
    Text="",TextColor3=Color3.fromRGB(180,220,255),TextScaled=true,
    Font=Enum.Font.Gotham,Parent=dailyPanel})
claimDailyBtn.MouseButton1Click:Connect(function()
    Remotes:WaitForChild("ClaimDaily"):FireServer()
end)

-- ── PANEL: Quests ─────────────────────────────────────────────────────────
local questPanel=makePanel("Quests")
questPanel.CanvasSize=UDim2.new(0,0,0,#Quests*90+20)
local questLayout=Instance.new("UIListLayout"); questLayout.Padding=UDim.new(0,6); questLayout.Parent=questPanel
Instance.new("UIPadding",questPanel).PaddingTop=UDim.new(0,8)
local questRows={}
for _, q in ipairs(Quests) do
    local qrow=Instance.new("Frame")
    qrow.Size=UDim2.new(1,-16,0,80); qrow.BackgroundColor3=Color3.fromRGB(20,30,50)
    qrow.BorderSizePixel=0; qrow.Parent=questPanel; corner(qrow)
    lbl({Size=UDim2.new(0.55,0,0.5,0),Position=UDim2.new(0,8,0,4),
        Text=q.emoji.."  "..q.name,TextColor3=Color3.fromRGB(220,220,255),
        TextScaled=true,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},qrow)
    lbl({Size=UDim2.new(0.55,0,0.4,0),Position=UDim2.new(0,8,0.5,2),
        Text=q.desc,TextColor3=Color3.fromRGB(160,160,200),TextScaled=true,
        Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},qrow)
    local rewardLbl=lbl({Size=UDim2.new(0.3,0,0.5,0),AnchorPoint=Vector2.new(1,0),
        Position=UDim2.new(1,-8,0,4),
        Text="+"..q.reward.amount..(q.reward.type=="rizz" and "💎" or "σ"),
        TextColor3=Color3.fromRGB(255,215,0),TextScaled=true,Font=Enum.Font.GothamBold},qrow)
    -- Progress bar background
    local pBg=Instance.new("Frame"); pBg.Size=UDim2.new(0.42,-4,0,10)
    pBg.Position=UDim2.new(0.57,2,0.58,2); pBg.BackgroundColor3=Color3.fromRGB(40,40,60)
    pBg.BorderSizePixel=0; pBg.Parent=qrow; corner(pBg,5)
    local pFill=Instance.new("Frame"); pFill.Size=UDim2.new(0,0,1,0)
    pFill.BackgroundColor3=Color3.fromRGB(80,200,255); pFill.BorderSizePixel=0; pFill.Parent=pBg; corner(pFill,5)
    questRows[q.id]={row=qrow, fill=pFill, reward=rewardLbl, req=q.req.amount or 1}
end

-- ── PANEL: Achievements ───────────────────────────────────────────────────
local achievePanel=makePanel("Achieve")
achievePanel.CanvasSize=UDim2.new(0,0,0,#Achievements*86+20)
local achieveLayout=Instance.new("UIListLayout"); achieveLayout.Padding=UDim.new(0,6); achieveLayout.Parent=achievePanel
Instance.new("UIPadding",achievePanel).PaddingTop=UDim.new(0,8)
local achieveRows={}
for _, a in ipairs(Achievements) do
    local arow=Instance.new("Frame")
    arow.Size=UDim2.new(1,-16,0,76); arow.BackgroundColor3=Color3.fromRGB(30,20,50)
    arow.BorderSizePixel=0; arow.BackgroundTransparency=0.5; arow.Parent=achievePanel; corner(arow)
    lbl({Size=UDim2.new(0.15,0,1,0),Text=a.emoji,TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.GothamBold},arow)
    lbl({Size=UDim2.new(0.55,0,0.55,0),Position=UDim2.new(0.15,4,0,4),
        Text=a.name,TextColor3=Color3.fromRGB(200,200,255),TextScaled=true,Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left},arow)
    lbl({Size=UDim2.new(0.55,0,0.4,0),Position=UDim2.new(0.15,4,0.55,2),
        Text=a.desc,TextColor3=Color3.fromRGB(150,150,210),TextScaled=true,Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left},arow)
    lbl({Size=UDim2.new(0.25,0,0.5,0),AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-6,0,6),
        Text="+"..a.reward.amount..(a.reward.type=="rizz" and "💎" or "σ"),
        TextColor3=Color3.fromRGB(255,215,0),TextScaled=true,Font=Enum.Font.GothamBold},arow)
    achieveRows[a.id]=arow
end

-- ── PANEL: Free Rewards ────────────────────────────────────────────────────
local freePanel=makePanel("Free")
freePanel.CanvasSize=UDim2.new(0,0,0,440)
Instance.new("UIPadding",freePanel).PaddingTop=UDim.new(0,10)
lbl({Size=UDim2.new(1,-16,0,40),Position=UDim2.new(0,8,0,10),
    Text="🎁  Free Rewards",TextColor3=Color3.fromRGB(100,255,200),
    TextScaled=true,Font=Enum.Font.GothamBold,Parent=freePanel})
local FREE_SLOTS_DEF={
    {id="slot1",label="15 min",emoji="⚡",reward="+10💎"},
    {id="slot2",label="1 hour", emoji="🔥",reward="+30💎"},
    {id="slot3",label="24 hours",emoji="💀",reward="+100💎"},
}
local COOLDOWN_SECS={slot1=900,slot2=3600,slot3=86400}
local freeSlotBtns={}; local freeSlotLabels={}
for i, slot in ipairs(FREE_SLOTS_DEF) do
    local sf=Instance.new("Frame")
    sf.Size=UDim2.new(1,-16,0,100); sf.Position=UDim2.new(0,8,0,56+(i-1)*112)
    sf.BackgroundColor3=Color3.fromRGB(20,50,40); sf.BorderSizePixel=0; sf.Parent=freePanel; corner(sf)
    lbl({Size=UDim2.new(0.6,0,0.5,0),Position=UDim2.new(0,10,0,6),
        Text=slot.emoji.."  "..slot.label.." Free — "..slot.reward,
        TextColor3=Color3.fromRGB(200,255,200),TextScaled=true,Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left},sf)
    local slbl=lbl({Size=UDim2.new(0.6,0,0.4,0),Position=UDim2.new(0,10,0.57,0),
        Text="Ready!",TextColor3=Color3.fromRGB(150,220,150),TextScaled=true,Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left},sf)
    local fsbtn=btn({Size=UDim2.new(0.3,0,0.65,0),AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-8,0.5,0),BackgroundColor3=Color3.fromRGB(0,140,80),
        Text="Claim",TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.GothamBold},sf)
    corner(fsbtn)
    local sid=slot.id
    fsbtn.MouseButton1Click:Connect(function()
        Remotes:WaitForChild("ClaimFreeReward"):FireServer(sid)
    end)
    freeSlotBtns[slot.id]=fsbtn; freeSlotLabels[slot.id]=slbl
end

-- ── Hatch cinematic ───────────────────────────────────────────────────────
local hatchOverlay=Instance.new("Frame")
hatchOverlay.Size=UDim2.new(1,0,1,0); hatchOverlay.BackgroundColor3=Color3.fromRGB(0,0,0)
hatchOverlay.BackgroundTransparency=1; hatchOverlay.ZIndex=30; hatchOverlay.Visible=false; hatchOverlay.Parent=screen
local hatchLbl=lbl({Size=UDim2.new(1,0,0.35,0),AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.new(0.5,0,0.45,0),Text="",TextColor3=Color3.fromRGB(255,215,0),
    TextScaled=true,Font=Enum.Font.GothamBold,ZIndex=31},hatchOverlay)
local function playHatchCinematic(petId, isDuplicate, rizzBonus)
    local petDef=petById[petId]
    if not petDef then return end
    local col=RARITY_COLORS[petDef.rarity] or Color3.fromRGB(255,255,255)
    -- Drumroll sound: plays during build-up, stops at reveal
    local _ss=game:GetService("SoundService")
    local drumroll=Instance.new("Sound")
    drumroll.SoundId="rbxassetid://4946458712"; drumroll.Volume=0.6; drumroll.Looped=true
    drumroll.Parent=_ss; drumroll:Play()
    hatchOverlay.Visible=true
    TweenService:Create(hatchOverlay,TweenInfo.new(0.25),{BackgroundTransparency=0.08}):Play()
    hatchLbl.Text=petDef.emoji
    hatchLbl.TextSize=1
    TweenService:Create(hatchLbl,TweenInfo.new(0.6,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{TextSize=160}):Play()
    task.wait(0.7)
    drumroll:Stop(); drumroll:Destroy()  -- reveal moment — stop drumroll here
    hatchLbl.Text=petDef.emoji.."\n"..petDef.rarity.." — "..petDef.name
    hatchLbl.TextColor3=col
    hatchLbl.TextSize=72
    if isDuplicate then
        task.wait(0.7)
        hatchLbl.Text=hatchLbl.Text.."\n(Duplicate! +"..rizzBonus.."💎)"
        hatchLbl.TextColor3=Color3.fromRGB(200,200,100)
        hatchLbl.TextSize=52
    end
    task.wait(1.2)
    TweenService:Create(hatchOverlay,TweenInfo.new(0.25),{BackgroundTransparency=1}):Play()
    task.wait(0.3)
    hatchOverlay.Visible=false
    hatchLbl.TextSize=72
end

-- ── Evolve Result cinematic ───────────────────────────────────────────────
local evolveOverlay=Instance.new("Frame")
evolveOverlay.Size=UDim2.new(1,0,1,0); evolveOverlay.BackgroundColor3=Color3.fromRGB(20,10,0)
evolveOverlay.BackgroundTransparency=1; evolveOverlay.ZIndex=32; evolveOverlay.Visible=false; evolveOverlay.Parent=screen
local evolveLbl=lbl({Size=UDim2.new(1,0,0.4,0),AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.new(0.5,0,0.45,0),Text="",TextColor3=Color3.fromRGB(255,215,0),
    TextScaled=true,Font=Enum.Font.GothamBold,ZIndex=33},evolveOverlay)
local function playEvolveCinematic(evolvedName, evolvedEmoji)
    evolveOverlay.Visible=true
    TweenService:Create(evolveOverlay,TweenInfo.new(0.3),{BackgroundTransparency=0.08}):Play()
    evolveLbl.Text="🌟"
    evolveLbl.TextSize=1
    TweenService:Create(evolveLbl,TweenInfo.new(0.7,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{TextSize=160}):Play()
    task.wait(0.8)
    evolveLbl.Text=evolvedEmoji.."\n"..evolvedName.."\n✨ Evolved!"
    evolveLbl.TextColor3=Color3.fromRGB(255,180,50)
    evolveLbl.TextSize=64
    task.wait(1.5)
    TweenService:Create(evolveOverlay,TweenInfo.new(0.3),{BackgroundTransparency=1}):Play()
    task.wait(0.35); evolveOverlay.Visible=false
end

-- ── Achievement popup ─────────────────────────────────────────────────────
local achievePopup=Instance.new("Frame")
achievePopup.Size=UDim2.new(0,320,0,84); achievePopup.AnchorPoint=Vector2.new(0.5,1)
achievePopup.Position=UDim2.new(0.5,0,1,-58); achievePopup.BackgroundColor3=Color3.fromRGB(40,30,60)
achievePopup.BackgroundTransparency=0.08; achievePopup.BorderSizePixel=0; achievePopup.ZIndex=25; achievePopup.Visible=false; achievePopup.Parent=screen; corner(achievePopup)
local achvLbl=lbl({Size=UDim2.new(1,-12,1,0),Position=UDim2.new(0,6,0,0),
    Text="",TextColor3=Color3.fromRGB(255,215,0),TextScaled=true,Font=Enum.Font.GothamBold,ZIndex=26},achievePopup)
local function showAchievePop(data)
    achvLbl.Text="🏅 "..data.name.."\n"..data.desc
    achievePopup.Visible=true
    task.delay(3, function() achievePopup.Visible=false end)
end

-- ── Floating sigma numbers ────────────────────────────────────────────────
local CRIT_COLORS={
    ["GIGACHAD!!"]=Color3.fromRGB(255,60,60),
    ["SIGMA!"]    =Color3.fromRGB(255,140,0),
    ["NICE"]      =Color3.fromRGB(255,215,0),
    [""]          =Color3.fromRGB(255,255,255),
}
local function spawnFloat(gain, critLabel, normX, normY)
    normX = normX or 0.5
    normY = normY or 0.72
    local fl=Instance.new("TextLabel")
    fl.Size=UDim2.new(0,180,0,52); fl.AnchorPoint=Vector2.new(0.5,0.5)
    fl.Position=UDim2.new(normX, math.random(-60,60), normY, 0)
    fl.BackgroundTransparency=1
    fl.TextColor3=CRIT_COLORS[critLabel] or Color3.fromRGB(255,255,255)
    fl.TextScaled=true; fl.Font=Enum.Font.GothamBold; fl.ZIndex=10
    fl.Text=critLabel~="" and (critLabel.."! +"..gain.."σ") or ("+"..gain.."σ")
    fl.Parent=screen
    TweenService:Create(fl,TweenInfo.new(0.75,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
        {Position=UDim2.new(normX, math.random(-60,60), normY-0.15, 0), TextTransparency=1}):Play()
    task.delay(0.85, function() fl:Destroy() end)
end

-- ── Prestige / Ascension buttons ─────────────────────────────────────────
prestigeBtn.MouseButton1Click:Connect(function()
    Remotes:WaitForChild("Prestige"):FireServer()
end)
ascendBtn.MouseButton1Click:Connect(function()
    -- Confirm modal
    local confirmed=false
    local modal=Instance.new("Frame")
    modal.Size=UDim2.new(0,350,0,160); modal.AnchorPoint=Vector2.new(0.5,0.5)
    modal.Position=UDim2.new(0.5,0,0.5,0); modal.BackgroundColor3=Color3.fromRGB(40,0,0)
    modal.ZIndex=40; modal.Parent=screen; corner(modal)
    lbl({Size=UDim2.new(1,-12,0.55,0),Position=UDim2.new(0,6,0,6),
        Text="✨ TRUE RESET\nAll progress resets. Permanent "..
             "multiplier gained.\nAscend?",
        TextColor3=Color3.fromRGB(255,180,50),TextScaled=true,Font=Enum.Font.Gotham,
        TextWrapped=true,ZIndex=41},modal)
    local yesBtn=btn({Size=UDim2.new(0.4,0,0.35,0),Position=UDim2.new(0.06,0,0.62,0),
        BackgroundColor3=Color3.fromRGB(180,20,20),Text="Yes, Ascend!",
        TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.GothamBold,ZIndex=41},modal)
    corner(yesBtn)
    local noBtn=btn({Size=UDim2.new(0.4,0,0.35,0),Position=UDim2.new(0.54,0,0.62,0),
        BackgroundColor3=Color3.fromRGB(40,80,40),Text="Cancel",
        TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.GothamBold,ZIndex=41},modal)
    corner(noBtn)
    yesBtn.MouseButton1Click:Connect(function()
        modal:Destroy(); Remotes:WaitForChild("Ascend"):FireServer()
    end)
    noBtn.MouseButton1Click:Connect(function() modal:Destroy() end)
end)

-- ── UpdateUI ─────────────────────────────────────────────────────────────
Remotes:WaitForChild("UpdateUI").OnClientEvent:Connect(function(data)
    sigmaLabel.Text="😎  "..tostring(data.sigma).." σ"
    petIncomeLabel.Text="🐾 "..tostring(data.petIncome).." σ/sec"
    multLabel.Text="x"..string.format("%.1f", data.multiplier).." per click"
    rizzLabel.Text="💎  "..tostring(data.rizzTokens).." Rizz"
    rankLabel.Text=data.rank.emoji.."  "..data.rank.name

    -- Prestige progress bar
    if data.nextRank then
        local prev=data.rank.sigmaRequired; local nxt=data.nextRank.sigmaRequired
        local pct=math.clamp((data.sigma-prev)/(nxt-prev),0,1)
        TweenService:Create(progBar,TweenInfo.new(0.2),{Size=UDim2.new(pct,0,1,0)}):Play()
    else
        progBar.Size=UDim2.new(1,0,1,0)
    end

    -- Prestige & Ascension buttons
    local canP=data.sigma>=(data.prestThresh or 10000)
    prestigeBtn.Visible=canP
    if canP then
        prestigeBtn.Text="🌌 PRESTIGE #"..(data.prestige+1)
        prestigeBtn.BackgroundColor3=Color3.fromRGB(120,0,180)
    end
    ascendBtn.Visible=data.ascendUnlocked == true
    if data.ascendUnlocked then
        local aMultStr=tostring(data.ascendMulti or 1)
        ascendBtn.Text="✨ ASCEND ("..aMultStr.."x)"
    end

    -- Spin boost
    if data.spinBoostLeft and data.spinBoostLeft > 0 then
        spinBoostLabel.Text="⚡ 2x BOOST "..data.spinBoostLeft.."s"
        spinBoostLabel.Visible=true
    else
        spinBoostLabel.Visible=false
    end

    -- Floating number
    if data.lastGain and data.lastGain>0 then
        spawnFloat(data.lastGain, data.critLabel or "", lastTapPos.X, lastTapPos.Y)
    end

    -- Upgrade affordability
    for _, u in ipairs(Upgrades) do
        local b=upgradeButtons[u.id]
        if b then
            local can=data.sigma>=u.cost
            b.BackgroundColor3=can and Color3.fromRGB(32,32,32) or Color3.fromRGB(20,20,20)
            b.TextColor3=can and Color3.fromRGB(255,255,255) or Color3.fromRGB(100,100,100)
        end
    end

    -- Rebuild pets panel
    rebuildMyPets(data.ownedPets, data.equippedPets, data.evolvedPets)

    -- Daily rewards UI
    if data.dailyStreak then
        dailyStrLbl.Text="Streak: "..data.dailyStreak.." day(s)"
        local streak=data.dailyStreak
        for i, df in ipairs(dailyDayFrames) do
            if i <= streak then
                df.BackgroundColor3=Color3.fromRGB(0,100,50)
            elseif i == streak+1 then
                df.BackgroundColor3=Color3.fromRGB(0,60,120)
            else
                df.BackgroundColor3=Color3.fromRGB(25,40,60)
            end
        end
        local now=os.time()
        local last=data.lastDailyClaim or 0
        local since=now-last
        if since < 20*3600 then
            local rem=20*3600-since
            local h=math.floor(rem/3600); local m=math.floor((rem%3600)/60)
            dailyCoolLbl.Text=string.format("Next claim in: %dh %dm", h, m)
            claimDailyBtn.BackgroundColor3=Color3.fromRGB(60,60,60)
        else
            dailyCoolLbl.Text="✅ Claim available!"
            claimDailyBtn.BackgroundColor3=Color3.fromRGB(0,120,200)
        end
    end

    -- Spin cooldown display
    if data.lastSpin then
        local now=os.time(); local since=now-(data.lastSpin or 0)
        if since < 6*3600 then
            local rem=6*3600-since
            local h=math.floor(rem/3600); local m=math.floor((rem%3600)/60)
            spinCooldownLbl.Text=string.format("Free spin in: %dh %dm", h, m)
            spinFreeBtn.BackgroundColor3=Color3.fromRGB(50,50,50)
        else
            spinCooldownLbl.Text="🎡 Free spin ready!"
            spinFreeBtn.BackgroundColor3=Color3.fromRGB(60,0,120)
        end
    end

    -- Free rewards cooldown display
    if data.freeSlotClaimed then
        local now=os.time()
        for _, slot in ipairs(FREE_SLOTS_DEF) do
            local last=data.freeSlotClaimed[slot.id] or 0
            local since=now-last
            local cd=COOLDOWN_SECS[slot.id] or 900
            local sBtn=freeSlotBtns[slot.id]; local sLbl=freeSlotLabels[slot.id]
            if sBtn and sLbl then
                if since < cd then
                    local rem=cd-since
                    local h=math.floor(rem/3600); local m=math.floor((rem%3600)/60); local s=rem%60
                    if h>0 then sLbl.Text=h.."h "..m.."m" else sLbl.Text=m.."m "..s.."s" end
                    sBtn.BackgroundColor3=Color3.fromRGB(50,50,50)
                else
                    sLbl.Text="✅ Ready!"
                    sBtn.BackgroundColor3=Color3.fromRGB(0,140,80)
                end
            end
        end
    end
end)

-- ── Quest updates ─────────────────────────────────────────────────────────
Remotes:WaitForChild("QuestUpdate").OnClientEvent:Connect(function(data)
    for _, q in ipairs(Quests) do
        local qr=questRows[q.id]
        if qr then
            local prog=data.questProgress[q.id] or 0
            local done=data.questDone[q.id]
            local pct=math.clamp(prog/(qr.req),0,1)
            TweenService:Create(qr.fill,TweenInfo.new(0.3),{Size=UDim2.new(pct,0,1,0)}):Play()
            if done then
                qr.row.BackgroundColor3=Color3.fromRGB(0,60,30)
                qr.reward.Text="✅"
            end
        end
    end
end)

-- ── Achievement unlock ────────────────────────────────────────────────────
Remotes:WaitForChild("AchieveUnlock").OnClientEvent:Connect(function(data)
    local arow=achieveRows[data.id]
    if arow then
        arow.BackgroundTransparency=0
        arow.BackgroundColor3=Color3.fromRGB(60,40,0)
    end
    showAchievePop(data)
end)

-- ── Hatch result ─────────────────────────────────────────────────────────
Remotes:WaitForChild("HatchResult").OnClientEvent:Connect(function(result)
    if result.skipCinematic then return end
    task.spawn(function()
        playHatchCinematic(result.petId, result.isDuplicate, result.rizzBonus or 0)
    end)
end)

-- ── Evolve result ─────────────────────────────────────────────────────────
Remotes:WaitForChild("EvolvePetResult").OnClientEvent:Connect(function(result)
    task.spawn(function()
        playEvolveCinematic(result.evolvedName, result.evolvedEmoji)
    end)
end)

-- ── Spin wheel result ─────────────────────────────────────────────────────
Remotes:WaitForChild("SpinResult").OnClientEvent:Connect(function(data)
    local prize=data.prize
    spinResultLbl.Text="🎡 You won: "..prize.emoji.."  "..prize.label.."!"
    showAnn("🎡 Spin reward: "..prize.emoji.."  "..prize.label)
end)

-- ── Auto-roll status ──────────────────────────────────────────────────────
Remotes:WaitForChild("AutoRollStatus").OnClientEvent:Connect(function(data)
    -- Update auto-roll button color on the egg row
    for _, child in ipairs(shopPanel:GetChildren()) do
        if child:IsA("Frame") and child:GetAttribute("EggId") == data.eggId then
            local arbtn=child:FindFirstChild("Auto")
            if arbtn then
                arbtn.BackgroundColor3 = data.active and Color3.fromRGB(0,160,60) or Color3.fromRGB(40,80,40)
                arbtn.Text = data.active and "■ Auto" or "▶ Auto"
            end
        end
    end
end)

-- ── Co-op boost ───────────────────────────────────────────────────────────
Remotes:WaitForChild("CoopBoost").OnClientEvent:Connect(function(active)
    coopLabel.Visible=active
    coopLabel.Text=active and "👥 Co-op Boost +20%!" or ""
end)

-- ── Leaderboard update ────────────────────────────────────────────────────
local MEDALS={"🥇","🥈","🥉","4️⃣","5️⃣"}
Remotes:WaitForChild("LeaderboardUpdate").OnClientEvent:Connect(function(top5)
    for i, row in ipairs(boardRows) do
        local entry=top5 and top5[i]
        if entry then
            local pre=entry.prestige>0 and " ⭐"..entry.prestige or ""
            row.Text=(MEDALS[i] or " ").." "..entry.name..pre.."  —  "..entry.sigma.."σ"
            row.BackgroundTransparency=0.3
        else
            row.Text="" ; row.BackgroundTransparency=1
        end
    end
end)

-- ── God mode ──────────────────────────────────────────────────────────────
Remotes:WaitForChild("GodModeActive").OnClientEvent:Connect(function()
    godLabel.Visible=true
    TweenService:Create(godFlash,TweenInfo.new(0.2),{BackgroundTransparency=0.7}):Play()
    task.delay(0.3, function()
        TweenService:Create(godFlash,TweenInfo.new(0.2),{BackgroundTransparency=1}):Play()
    end)
end)
Remotes:WaitForChild("GodModeEnded").OnClientEvent:Connect(function()
    godLabel.Visible=false
end)

-- ── Event notification ─────────────────────────────────────────────────────
Remotes:WaitForChild("EventNotify").OnClientEvent:Connect(function(event)
    if event then
        eventBanner.Visible=true
        eventBanner.Text="⚡ EVENT: "..event.name.."  — "..event.description
    else
        eventBanner.Visible=false
    end
end)

-- ── Server announce ────────────────────────────────────────────────────────
Remotes:WaitForChild("ServerAnnounce").OnClientEvent:Connect(function(msg)
    if msg and msg.text then showAnn(msg.text) end
end)

-- ── Duel events ────────────────────────────────────────────────────────────
Remotes:WaitForChild("DuelInvite").OnClientEvent:Connect(function(data)
    duelStatus.Text="⚔️ "..data.challengerName.." challenged you to a duel!\n(Tap Accept or Decline in Duels tab)"
    showPanel("Duels")
    -- Auto-add accept/decline if not present
    if not duelPanel:FindFirstChild("AcceptBtn") then
        local abtn=btn({Name="AcceptBtn",Size=UDim2.new(0.4,0,0,44),Position=UDim2.new(0.05,0,0,300),
            BackgroundColor3=Color3.fromRGB(0,140,60),Text="✅ Accept",
            TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.GothamBold},duelPanel)
        corner(abtn)
        abtn.MouseButton1Click:Connect(function()
            Remotes:WaitForChild("DuelAccept"):FireServer()
            abtn:Destroy()
            local db=duelPanel:FindFirstChild("DeclineBtn"); if db then db:Destroy() end
        end)
        local dbtn=btn({Name="DeclineBtn",Size=UDim2.new(0.4,0,0,44),Position=UDim2.new(0.55,0,0,300),
            BackgroundColor3=Color3.fromRGB(140,0,0),Text="❌ Decline",
            TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.GothamBold},duelPanel)
        corner(dbtn)
        dbtn.MouseButton1Click:Connect(function()
            Remotes:WaitForChild("DuelDecline"):FireServer()
            dbtn:Destroy()
            local ab=duelPanel:FindFirstChild("AcceptBtn"); if ab then ab:Destroy() end
        end)
    end
end)

Remotes:WaitForChild("DuelStart").OnClientEvent:Connect(function(data)
    duelClickBtn.Visible=true
    duelStatus.Text="⚔️ DUEL vs "..data.opponentName.."! CLICK AS FAST AS YOU CAN!"
end)
Remotes:WaitForChild("DuelUpdate").OnClientEvent:Connect(function(data)
    duelStatus.Text=string.format("⚔️ You: %d  |  Them: %d  |  ⏱ %ds",
        data.myClicks, data.theirClicks, data.timeLeft)
end)
Remotes:WaitForChild("DuelResult").OnClientEvent:Connect(function(data)
    duelClickBtn.Visible=false
    local won=(data.winnerName==player.Name)
    duelStatus.Text=won and ("🏆 You won the duel! +"..data.sigmaStake.."σ")
        or ("💀 You lost the duel. -"..data.sigmaStake.."σ")
end)
Remotes:WaitForChild("DuelCancel").OnClientEvent:Connect(function(data)
    duelClickBtn.Visible=false
    local reason=data and data.reason
    duelStatus.Text=reason=="declined" and "❌ Challenge declined."
        or reason=="opponent_left" and "❌ Opponent left the game."
        or "❌ Duel cancelled."
end)

-- ── Space key click ──────────────────────────────────────────────────────
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Space then
        ClickRemote:FireServer()
        spawnTapRipple(Vector2.new(0.5, 0.65))  -- visual feedback at screen centre
    end
end)

-- ── Default panel on load ─────────────────────────────────────────────────
-- No default panel opened on load — game world stays visible until player taps a pill
