-- UIManager.client.lua  (V3)
-- Full GUI: stats, upgrades, egg shop + hatch cinematic, duel system,
-- leaderboard, god mode flash, event/announce banners, co-op indicator

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

-- ── Util ──────────────────────────────────────────────────────────────────
local function corner(p, r)
    local c = Instance.new("UICorner") ; c.CornerRadius = UDim.new(0,r or 10) ; c.Parent=p
end
local function lbl(props, parent)
    local l = Instance.new("TextLabel") ; l.BackgroundTransparency=1
    for k,v in pairs(props) do l[k]=v end ; l.Parent=parent ; return l
end
local function btn(props, parent)
    local b = Instance.new("TextButton") ; b.BorderSizePixel=0
    for k,v in pairs(props) do b[k]=v end ; b.Parent=parent ; return b
end

-- ── Constants ─────────────────────────────────────────────────────────────
local RARITY_COLORS = {
    Common    = Color3.fromRGB(190,190,190),
    Rare      = Color3.fromRGB(80,140,255),
    Legendary = Color3.fromRGB(255,170,0),
}
local EGG_COLORS = {}
for _, e in ipairs(Eggs) do EGG_COLORS[e.id] = e.color end

-- ── Root ScreenGui ─────────────────────────────────────────────────────────
local screen = Instance.new("ScreenGui")
screen.Name="SigmaGui" ; screen.ResetOnSpawn=false
screen.IgnoreGuiInset=true ; screen.Parent=playerGui

-- ── TOP RIGHT: Rizz counter ───────────────────────────────────────────────
local rizzFrame = Instance.new("Frame")
rizzFrame.Size=UDim2.new(0,180,0,46) ; rizzFrame.Position=UDim2.new(1,-190,0,12)
rizzFrame.BackgroundColor3=Color3.fromRGB(55,0,90) ; rizzFrame.BackgroundTransparency=0.05
rizzFrame.BorderSizePixel=0 ; rizzFrame.Parent=screen
corner(rizzFrame)
Instance.new("UIStroke",rizzFrame).Color=Color3.fromRGB(140,60,220)

local rizzLabel = lbl({Name="RizzLabel",Size=UDim2.new(1,-8,1,0),Position=UDim2.new(0,4,0,0),
    Text="💎  0 Rizz",TextColor3=Color3.fromRGB(230,180,255),TextScaled=true,Font=Enum.Font.GothamBold},rizzFrame)

-- ── TOP CENTER: Sigma + pet income ────────────────────────────────────────
local sigmaFrame = Instance.new("Frame")
sigmaFrame.Size=UDim2.new(0,320,0,76) ; sigmaFrame.Position=UDim2.new(0.5,-160,0,12)
sigmaFrame.BackgroundColor3=Color3.fromRGB(12,12,12) ; sigmaFrame.BackgroundTransparency=0.15
sigmaFrame.BorderSizePixel=0 ; sigmaFrame.Parent=screen
corner(sigmaFrame)

local sigmaLabel = lbl({Name="SigmaLabel",Size=UDim2.new(1,0,0.6,0),
    Text="😎  0 σ",TextColor3=Color3.fromRGB(255,215,0),TextScaled=true,Font=Enum.Font.GothamBold},sigmaFrame)

local petIncomeLabel = lbl({Name="PetLabel",Size=UDim2.new(1,0,0.4,0),Position=UDim2.new(0,0,0.6,0),
    Text="🐾 0 σ/sec",TextColor3=Color3.fromRGB(110,230,110),TextScaled=true,Font=Enum.Font.Gotham},sigmaFrame)

-- ── Rank + progress ───────────────────────────────────────────────────────
local rankFrame = Instance.new("Frame")
rankFrame.Size=UDim2.new(0,320,0,42) ; rankFrame.Position=UDim2.new(0.5,-160,0,92)
rankFrame.BackgroundColor3=Color3.fromRGB(12,12,12) ; rankFrame.BackgroundTransparency=0.15
rankFrame.BorderSizePixel=0 ; rankFrame.Parent=screen
corner(rankFrame)

local rankLabel = lbl({Name="RankLabel",Size=UDim2.new(1,0,0.6,0),
    Text="🤡  NPC",TextColor3=Color3.fromRGB(220,220,220),TextScaled=true,Font=Enum.Font.GothamBold},rankFrame)

local progBg = Instance.new("Frame")
progBg.Size=UDim2.new(1,-16,0,6) ; progBg.Position=UDim2.new(0,8,1,-10)
progBg.BackgroundColor3=Color3.fromRGB(50,50,50) ; progBg.BorderSizePixel=0 ; progBg.Parent=rankFrame
corner(progBg,3)

local progBar = Instance.new("Frame")
progBar.Name="ProgressBar" ; progBar.Size=UDim2.new(0,0,1,0)
progBar.BackgroundColor3=Color3.fromRGB(255,215,0) ; progBar.BorderSizePixel=0 ; progBar.Parent=progBg
corner(progBar,3)

-- ── Multiplier + co-op label ──────────────────────────────────────────────
local multLabel = lbl({Name="MultLabel",Size=UDim2.new(0,200,0,22),Position=UDim2.new(0.5,-100,1,-334),
    Text="x1 per click",TextColor3=Color3.fromRGB(180,180,180),TextScaled=true,Font=Enum.Font.Gotham},screen)

local coopLabel = lbl({Name="CoopLabel",Size=UDim2.new(0,200,0,20),Position=UDim2.new(0.5,-100,1,-314),
    Text="",TextColor3=Color3.fromRGB(100,255,200),TextScaled=true,Font=Enum.Font.Gotham,Visible=false},screen)

-- ── Combo bar ─────────────────────────────────────────────────────────────
local comboBar = Instance.new("Frame")
comboBar.Name="ComboBar" ; comboBar.Size=UDim2.new(0,200,0,22)
comboBar.Position=UDim2.new(0.5,-100,1,-306) ; comboBar.BackgroundColor3=Color3.fromRGB(30,30,30)
comboBar.BorderSizePixel=0 ; comboBar.Parent=screen
corner(comboBar,4)

local comboFill = Instance.new("Frame")
comboFill.Name="ComboFill" ; comboFill.Size=UDim2.new(0,0,1,0)
comboFill.BackgroundColor3=Color3.fromRGB(255,215,0) ; comboFill.BorderSizePixel=0 ; comboFill.Parent=comboBar
corner(comboFill,4)

lbl({Name="ComboLabel",Size=UDim2.new(1,0,1,0),Text="0 / 5 for COMBO",
    TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.GothamBold,ZIndex=2},comboBar)

-- ── Click button ──────────────────────────────────────────────────────────
local clickButton = Instance.new("TextButton")
clickButton.Name="ClickButton" ; clickButton.Size=UDim2.new(0,200,0,200)
clickButton.Position=UDim2.new(0.5,-100,1,-284) ; clickButton.BackgroundColor3=Color3.fromRGB(255,215,0)
clickButton.BorderSizePixel=0 ; clickButton.Text="😎\nCLICK"
clickButton.TextColor3=Color3.fromRGB(0,0,0) ; clickButton.TextScaled=true
clickButton.Font=Enum.Font.GothamBold ; clickButton.Parent=screen
corner(clickButton,100)

-- ── Prestige button (hidden until threshold) ─────────────────────────────
local prestigeBtn = btn({Name="PrestigeButton",Size=UDim2.new(0,160,0,40),
    AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,1,-100),
    BackgroundColor3=Color3.fromRGB(80,0,120),Text="🌌 PRESTIGE",
    TextColor3=Color3.fromRGB(200,150,255),TextScaled=true,Font=Enum.Font.GothamBold,
    Visible=false},screen)
corner(prestigeBtn)
prestigeBtn.MouseButton1Click:Connect(function()
    Remotes:WaitForChild("Prestige"):FireServer()
end)

-- ── Bottom nav row ────────────────────────────────────────────────────────
local NAV_Y = UDim2.new(1,-52)
local function navBtn(x,text,bg,tc)
    local b = btn({Size=UDim2.new(0,110,0,42),Position=UDim2.new(0,x,1,-52),
        BackgroundColor3=bg,Text=text,TextColor3=tc,TextScaled=true,Font=Enum.Font.GothamBold},screen)
    corner(b) ; return b
end
local petNavBtn  = navBtn(5,   "🐾 Pets",     Color3.fromRGB(0,75,35),   Color3.fromRGB(150,255,150))
local duelNavBtn = navBtn(122, "⚔️ Duel",     Color3.fromRGB(90,0,0),    Color3.fromRGB(255,150,150))
local boardBtn   = navBtn(239, "🏆 Board",    Color3.fromRGB(60,45,0),    Color3.fromRGB(255,215,0))
local shopBtn    = navBtn(356, "⬆️ Upgrades", Color3.fromRGB(30,30,30),   Color3.fromRGB(255,255,255))

-- ── Upgrade shop panel ────────────────────────────────────────────────────
local shopFrame = Instance.new("Frame")
shopFrame.Name="ShopFrame" ; shopFrame.Size=UDim2.new(0,300,0,420)
shopFrame.Position=UDim2.new(1,-310,1,-478) ; shopFrame.BackgroundColor3=Color3.fromRGB(16,16,16)
shopFrame.BackgroundTransparency=0.05 ; shopFrame.BorderSizePixel=0
shopFrame.Visible=false ; shopFrame.Parent=screen
corner(shopFrame,14)
lbl({Size=UDim2.new(1,0,0,42),Text="⬆️  UPGRADES",TextColor3=Color3.fromRGB(255,215,0),
    TextScaled=true,Font=Enum.Font.GothamBold},shopFrame)

local upgradeScroll = Instance.new("ScrollingFrame")
upgradeScroll.Name="UpgradeList" ; upgradeScroll.Size=UDim2.new(1,-12,1,-50)
upgradeScroll.Position=UDim2.new(0,6,0,46) ; upgradeScroll.BackgroundTransparency=1
upgradeScroll.BorderSizePixel=0 ; upgradeScroll.ScrollBarThickness=4
upgradeScroll.CanvasSize=UDim2.new(0,0,0,#Upgrades*72) ; upgradeScroll.Parent=shopFrame
local ul=Instance.new("UIListLayout") ; ul.Padding=UDim.new(0,5) ; ul.Parent=upgradeScroll

local BuyUpgrade=Remotes:WaitForChild("BuyUpgrade")
local upgradeButtons={}
for _,u in ipairs(Upgrades) do
    local b=btn({Name="U_"..u.id,Size=UDim2.new(1,0,0,66),BackgroundColor3=Color3.fromRGB(32,32,32),
        TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.Gotham},upgradeScroll)
    corner(b,8)
    local fx=u.effect=="click_multiplier" and (u.value.."x click") or ("+"..u.value.." σ/sec")
    b.Text=u.name.."\n"..fx.."  |  "..u.cost.." σ"
    upgradeButtons[u.id]=b
    b.MouseButton1Click:Connect(function() BuyUpgrade:FireServer(u.id) end)
end
shopBtn.MouseButton1Click:Connect(function()
    shopFrame.Visible=not shopFrame.Visible
    if shopFrame.Visible then petPanel.Visible=false ; duelPanel.Visible=false ; boardPanel.Visible=false end
end)

-- ── Pet shop panel ────────────────────────────────────────────────────────
local petPanel = Instance.new("Frame")
petPanel.Name="PetPanel" ; petPanel.Size=UDim2.new(0,330,0,490)
petPanel.Position=UDim2.new(0,5,1,-548) ; petPanel.BackgroundColor3=Color3.fromRGB(8,22,12)
petPanel.BackgroundTransparency=0.05 ; petPanel.BorderSizePixel=0
petPanel.Visible=false ; petPanel.Parent=screen
corner(petPanel,14)
lbl({Size=UDim2.new(1,0,0,42),Text="🐾  PETS",
    TextColor3=Color3.fromRGB(150,255,150),TextScaled=true,Font=Enum.Font.GothamBold},petPanel)

local petBuyTab=btn({Size=UDim2.new(0.5,0,0,32),Position=UDim2.new(0,0,0,44),
    BackgroundColor3=Color3.fromRGB(0,100,50),Text="🥚 Hatch Eggs",
    TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.GothamBold},petPanel)
local petMyTab=btn({Size=UDim2.new(0.5,0,0,32),Position=UDim2.new(0.5,0,0,44),
    BackgroundColor3=Color3.fromRGB(30,30,30),Text="🎒 My Pets",
    TextColor3=Color3.fromRGB(180,180,180),TextScaled=true,Font=Enum.Font.GothamBold},petPanel)

-- Egg buy scroll
local eggScroll=Instance.new("ScrollingFrame")
eggScroll.Size=UDim2.new(1,-12,1,-80) ; eggScroll.Position=UDim2.new(0,6,0,80)
eggScroll.BackgroundTransparency=1 ; eggScroll.BorderSizePixel=0
eggScroll.ScrollBarThickness=4 ; eggScroll.CanvasSize=UDim2.new(0,0,0,#Eggs*150)
eggScroll.Visible=true ; eggScroll.Parent=petPanel
local eggUL=Instance.new("UIListLayout") ; eggUL.Padding=UDim.new(0,8) ; eggUL.Parent=eggScroll

-- My pets scroll
local myPetsScroll=Instance.new("ScrollingFrame")
myPetsScroll.Size=UDim2.new(1,-12,1,-80) ; myPetsScroll.Position=UDim2.new(0,6,0,80)
myPetsScroll.BackgroundTransparency=1 ; myPetsScroll.BorderSizePixel=0
myPetsScroll.ScrollBarThickness=4 ; myPetsScroll.CanvasSize=UDim2.new(0,0,0,400)
myPetsScroll.Visible=false ; myPetsScroll.Parent=petPanel
local myUL=Instance.new("UIListLayout") ; myUL.Padding=UDim.new(0,5) ; myUL.Parent=myPetsScroll

local HatchEgg   = Remotes:WaitForChild("HatchEgg")
local EquipPet   = Remotes:WaitForChild("EquipPet")
local ExchangePet= Remotes:WaitForChild("ExchangePet")

petBuyTab.MouseButton1Click:Connect(function()
    eggScroll.Visible=true ; myPetsScroll.Visible=false
    petBuyTab.BackgroundColor3=Color3.fromRGB(0,100,50) ; petMyTab.BackgroundColor3=Color3.fromRGB(30,30,30)
end)
petMyTab.MouseButton1Click:Connect(function()
    eggScroll.Visible=false ; myPetsScroll.Visible=true
    petMyTab.BackgroundColor3=Color3.fromRGB(0,100,50) ; petBuyTab.BackgroundColor3=Color3.fromRGB(30,30,30)
end)
petNavBtn.MouseButton1Click:Connect(function()
    petPanel.Visible=not petPanel.Visible
    if petPanel.Visible then shopFrame.Visible=false ; duelPanel.Visible=false ; boardPanel.Visible=false end
end)

-- Egg cards (static — costs/rarities never change)
for _,egg in ipairs(Eggs) do
    local card=Instance.new("Frame")
    card.Size=UDim2.new(1,0,0,140) ; card.BackgroundColor3=Color3.fromRGB(18,35,20)
    card.BorderSizePixel=0 ; card.Parent=eggScroll
    corner(card,10)
    -- Egg emoji
    lbl({Size=UDim2.new(0,80,1,-10),Position=UDim2.new(0,5,0,5),
        Text=egg.emoji,TextColor3=egg.color,TextScaled=true,Font=Enum.Font.GothamBold},card)
    -- Name + cost
    lbl({Size=UDim2.new(1,-100,0,40),Position=UDim2.new(0,90,0,8),
        Text=egg.name.."  💎 "..egg.cost.." Rizz",
        TextColor3=egg.color,TextScaled=true,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},card)
    -- Rarity preview
    local w=egg.weights
    lbl({Size=UDim2.new(1,-100,0,28),Position=UDim2.new(0,90,0,48),
        Text="🌟 Leg "..w.Legendary.."% | 💙 Rare "..w.Rare.."% | 🥚 Com "..w.Common.."%",
        TextColor3=Color3.fromRGB(180,180,180),TextScaled=true,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},card)
    -- Hatch button
    local hatchBtn=btn({Size=UDim2.new(1,-100,0,38),Position=UDim2.new(0,90,1,-48),
        BackgroundColor3=egg.color,Text="🥚 Hatch!",
        TextColor3=Color3.fromRGB(0,0,0),TextScaled=true,Font=Enum.Font.GothamBold},card)
    corner(hatchBtn,8)
    local eId=egg.id
    hatchBtn.MouseButton1Click:Connect(function() HatchEgg:FireServer(eId) end)
end

-- My pets rebuild (called on every UpdateUI)
local function rebuildMyPets(ownedPets, equippedPets)
    for _,c in ipairs(myPetsScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local equippedSet={}
    for _,id in ipairs(equippedPets or {}) do equippedSet[id]=true end
    local rows=0
    for _,pet in ipairs(Pets) do
        local key=tostring(pet.id)
        local count=(ownedPets and ownedPets[key]) or 0
        if count>0 then
            rows+=1
            local row=Instance.new("Frame")
            row.Size=UDim2.new(1,0,0,80) ; row.BackgroundColor3=equippedSet[pet.id] and Color3.fromRGB(0,70,35) or Color3.fromRGB(16,30,18)
            row.BorderSizePixel=0 ; row.Parent=myPetsScroll
            corner(row,8)
            lbl({Size=UDim2.new(0,52,1,0),Text=pet.emoji,TextColor3=RARITY_COLORS[pet.rarity] or Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.GothamBold},row)
            lbl({Size=UDim2.new(1,-160,0,30),Position=UDim2.new(0,56,0,4),
                Text=pet.name.." x"..count,TextColor3=RARITY_COLORS[pet.rarity] or Color3.fromRGB(255,255,255),
                TextScaled=true,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},row)
            lbl({Size=UDim2.new(1,-160,0,24),Position=UDim2.new(0,56,0,36),
                Text="+"..pet.sigmaPerSec.." σ/sec",TextColor3=Color3.fromRGB(150,255,150),
                TextScaled=true,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},row)
            local equipBtn=btn({Size=UDim2.new(0,90,0,30),Position=UDim2.new(1,-98,0,8),
                BackgroundColor3=equippedSet[pet.id] and Color3.fromRGB(0,140,70) or Color3.fromRGB(40,40,40),
                Text=equippedSet[pet.id] and "✅ Equipped" or "Equip",
                TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.Gotham},row)
            corner(equipBtn,6)
            local pid=pet.id
            equipBtn.MouseButton1Click:Connect(function() EquipPet:FireServer(pid) end)
            if count>1 then
                local exchBtn=btn({Size=UDim2.new(0,90,0,28),Position=UDim2.new(1,-98,0,44),
                    BackgroundColor3=Color3.fromRGB(60,0,80),
                    Text="♻️ Exchange",TextColor3=Color3.fromRGB(200,150,255),
                    TextScaled=true,Font=Enum.Font.Gotham},row)
                corner(exchBtn,6)
                exchBtn.MouseButton1Click:Connect(function() ExchangePet:FireServer(pid) end)
            end
        end
    end
    myPetsScroll.CanvasSize=UDim2.new(0,0,0,rows*88)
end

-- ── Leaderboard panel ─────────────────────────────────────────────────────
local boardPanel = Instance.new("Frame")
boardPanel.Name="BoardPanel" ; boardPanel.Size=UDim2.new(0,280,0,290)
boardPanel.Position=UDim2.new(0,239,1,-348) ; boardPanel.BackgroundColor3=Color3.fromRGB(18,14,0)
boardPanel.BackgroundTransparency=0.05 ; boardPanel.BorderSizePixel=0
boardPanel.Visible=false ; boardPanel.Parent=screen
corner(boardPanel,14)
Instance.new("UIStroke",boardPanel).Color=Color3.fromRGB(255,215,0)

lbl({Size=UDim2.new(1,0,0,42),Text="🏆  SIGMA LEADERBOARD",
    TextColor3=Color3.fromRGB(255,215,0),TextScaled=true,Font=Enum.Font.GothamBold},boardPanel)

local boardRows={}
for i=1,5 do
    local r=lbl({Size=UDim2.new(1,-16,0,42),Position=UDim2.new(0,8,0,42+i*46),
        Text="",TextColor3=Color3.fromRGB(220,220,220),TextScaled=true,
        Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},boardPanel)
    r.BackgroundColor3=Color3.fromRGB(28,24,0) ; r.BackgroundTransparency=0.4
    boardRows[i]=r
end
boardBtn.MouseButton1Click:Connect(function()
    boardPanel.Visible=not boardPanel.Visible
    if boardPanel.Visible then shopFrame.Visible=false ; petPanel.Visible=false ; duelPanel.Visible=false end
end)

-- ── Duel panel ────────────────────────────────────────────────────────────
local duelPanel = Instance.new("Frame")
duelPanel.Name="DuelPanel" ; duelPanel.Size=UDim2.new(0,300,0,390)
duelPanel.Position=UDim2.new(0,122,1,-448) ; duelPanel.BackgroundColor3=Color3.fromRGB(25,5,5)
duelPanel.BackgroundTransparency=0.05 ; duelPanel.BorderSizePixel=0
duelPanel.Visible=false ; duelPanel.Parent=screen
corner(duelPanel,14)
Instance.new("UIStroke",duelPanel).Color=Color3.fromRGB(200,50,50)

lbl({Size=UDim2.new(1,0,0,42),Text="⚔️  SIGMA DUEL",
    TextColor3=Color3.fromRGB(255,120,120),TextScaled=true,Font=Enum.Font.GothamBold},duelPanel)

-- Duel challenge tab
local duelChallengeTab = Instance.new("Frame")
duelChallengeTab.Size=UDim2.new(1,0,1,-46) ; duelChallengeTab.Position=UDim2.new(0,0,0,46)
duelChallengeTab.BackgroundTransparency=1 ; duelChallengeTab.Parent=duelPanel

local duelNoOpp = lbl({Size=UDim2.new(1,0,0,40),Position=UDim2.new(0,0,0,10),
    Text="No opponents online",TextColor3=Color3.fromRGB(130,130,130),
    TextScaled=true,Font=Enum.Font.Gotham},duelChallengeTab)

local duelScroll=Instance.new("ScrollingFrame")
duelScroll.Size=UDim2.new(1,-12,1,-8) ; duelScroll.Position=UDim2.new(0,6,0,4)
duelScroll.BackgroundTransparency=1 ; duelScroll.BorderSizePixel=0
duelScroll.ScrollBarThickness=4 ; duelScroll.CanvasSize=UDim2.new(0,0,0,0)
duelScroll.Parent=duelChallengeTab
local duelSL=Instance.new("UIListLayout") ; duelSL.Padding=UDim.new(0,5) ; duelSL.Parent=duelScroll

-- Active duel tab (hidden until duel starts)
local duelActiveTab = Instance.new("Frame")
duelActiveTab.Size=UDim2.new(1,0,1,-46) ; duelActiveTab.Position=UDim2.new(0,0,0,46)
duelActiveTab.BackgroundTransparency=1 ; duelActiveTab.Visible=false ; duelActiveTab.Parent=duelPanel

local duelVsLabel=lbl({Size=UDim2.new(1,0,0,40),Position=UDim2.new(0,0,0,5),
    Text="vs. ???",TextColor3=Color3.fromRGB(255,200,200),TextScaled=true,Font=Enum.Font.GothamBold},duelActiveTab)
local duelTimerLabel=lbl({Size=UDim2.new(1,0,0,36),Position=UDim2.new(0,0,0,48),
    Text="⏱ 30s",TextColor3=Color3.fromRGB(255,215,0),TextScaled=true,Font=Enum.Font.GothamBold},duelActiveTab)
local duelScoreLabel=lbl({Size=UDim2.new(1,0,0,36),Position=UDim2.new(0,0,0,88),
    Text="Me: 0  |  Them: 0",TextColor3=Color3.fromRGB(200,200,200),TextScaled=true,Font=Enum.Font.Gotham},duelActiveTab)

duelNavBtn.MouseButton1Click:Connect(function()
    duelPanel.Visible=not duelPanel.Visible
    if duelPanel.Visible then shopFrame.Visible=false ; petPanel.Visible=false ; boardPanel.Visible=false end
end)

local DuelChallenge=Remotes:WaitForChild("DuelChallenge")
local DuelAccept   =Remotes:WaitForChild("DuelAccept")
local DuelDecline  =Remotes:WaitForChild("DuelDecline")
local DuelClick    =Remotes:WaitForChild("DuelClick")
local isDueling    = false

-- Connect click button to also fire DuelClick while in a duel
clickButton.MouseButton1Click:Connect(function()
    if isDueling then DuelClick:FireServer() end
end)
UIS.InputBegan:Connect(function(inp,gp)
    if gp then return end
    if isDueling and inp.KeyCode==Enum.KeyCode.Space then DuelClick:FireServer() end
end)

-- Online players list
Remotes:WaitForChild("OnlinePlayers").OnClientEvent:Connect(function(names)
    for _,c in ipairs(duelScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local myName=player.Name
    local others={}
    for _,n in ipairs(names) do if n~=myName then table.insert(others,n) end end
    duelNoOpp.Visible=#others==0
    duelScroll.CanvasSize=UDim2.new(0,0,0,#others*58)
    for _,name in ipairs(others) do
        local row=Instance.new("Frame")
        row.Size=UDim2.new(1,0,0,52) ; row.BackgroundColor3=Color3.fromRGB(35,10,10)
        row.BorderSizePixel=0 ; row.Parent=duelScroll
        corner(row,8)
        lbl({Size=UDim2.new(1,-110,1,0),Position=UDim2.new(0,8,0,0),
            Text=name,TextColor3=Color3.fromRGB(255,200,200),TextScaled=true,
            Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},row)
        local cBtn=btn({Size=UDim2.new(0,96,0,32),Position=UDim2.new(1,-102,0.5,-16),
            BackgroundColor3=Color3.fromRGB(140,0,0),Text="⚔️ Challenge",
            TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.Gotham},row)
        corner(cBtn,6)
        local n2=name
        cBtn.MouseButton1Click:Connect(function() DuelChallenge:FireServer(n2) end)
    end
end)

-- ── Duel invite modal ─────────────────────────────────────────────────────
local inviteModal = Instance.new("Frame")
inviteModal.Size=UDim2.new(0,380,0,160) ; inviteModal.AnchorPoint=Vector2.new(0.5,0.5)
inviteModal.Position=UDim2.new(0.5,0,0.5,0) ; inviteModal.BackgroundColor3=Color3.fromRGB(20,5,5)
inviteModal.BackgroundTransparency=0.05 ; inviteModal.BorderSizePixel=0
inviteModal.ZIndex=50 ; inviteModal.Visible=false ; inviteModal.Parent=screen
corner(inviteModal,14)
Instance.new("UIStroke",inviteModal).Color=Color3.fromRGB(200,50,50)

local inviteLbl=lbl({Size=UDim2.new(1,0,0,56),Position=UDim2.new(0,0,0,8),
    Text="⚔️ ??? challenged you!",TextColor3=Color3.fromRGB(255,150,150),
    TextScaled=true,Font=Enum.Font.GothamBold,ZIndex=51},inviteModal)
local acceptBtn=btn({Size=UDim2.new(0.45,0,0,44),Position=UDim2.new(0.03,0,1,-52),
    BackgroundColor3=Color3.fromRGB(0,120,50),Text="✅ Accept",
    TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.GothamBold,ZIndex=51},inviteModal)
corner(acceptBtn)
local declineBtn=btn({Size=UDim2.new(0.45,0,0,44),Position=UDim2.new(0.52,0,1,-52),
    BackgroundColor3=Color3.fromRGB(120,0,0),Text="❌ Decline",
    TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.GothamBold,ZIndex=51},inviteModal)
corner(declineBtn)

acceptBtn.MouseButton1Click:Connect(function() DuelAccept:FireServer() ; inviteModal.Visible=false end)
declineBtn.MouseButton1Click:Connect(function() DuelDecline:FireServer() ; inviteModal.Visible=false end)

Remotes:WaitForChild("DuelInvite").OnClientEvent:Connect(function(data)
    inviteLbl.Text="⚔️ "..data.challengerName.." challenged you to a Sigma Duel!"
    inviteModal.Visible=true
    task.delay(15, function() inviteModal.Visible=false end)
end)

-- Duel start
Remotes:WaitForChild("DuelStart").OnClientEvent:Connect(function(data)
    isDueling=true ; inviteModal.Visible=false
    duelVsLabel.Text="⚔️ vs. "..data.opponentName
    duelChallengeTab.Visible=false ; duelActiveTab.Visible=true
    duelPanel.Visible=true
end)

-- Duel update
Remotes:WaitForChild("DuelUpdate").OnClientEvent:Connect(function(data)
    duelTimerLabel.Text="⏱ "..data.timeLeft.."s"
    local mine=data.myClicks or 0 ; local theirs=data.theirClicks or 0
    duelScoreLabel.Text="Me: "..mine.."  |  Them: "..theirs
    duelScoreLabel.TextColor3=mine>=theirs and Color3.fromRGB(100,255,100) or Color3.fromRGB(255,100,100)
end)

-- Duel result popup
local duelResultPopup = Instance.new("Frame")
duelResultPopup.Size=UDim2.new(0,340,0,100) ; duelResultPopup.AnchorPoint=Vector2.new(0.5,0)
duelResultPopup.Position=UDim2.new(0.5,0,0,160) ; duelResultPopup.BackgroundColor3=Color3.fromRGB(15,15,15)
duelResultPopup.BackgroundTransparency=0.05 ; duelResultPopup.BorderSizePixel=0
duelResultPopup.ZIndex=48 ; duelResultPopup.Visible=false ; duelResultPopup.Parent=screen
corner(duelResultPopup,14)
local duelResultLbl=lbl({Size=UDim2.new(1,0,1,0),Text="",
    TextColor3=Color3.fromRGB(255,215,0),TextScaled=true,Font=Enum.Font.GothamBold,ZIndex=49},duelResultPopup)

Remotes:WaitForChild("DuelResult").OnClientEvent:Connect(function(data)
    isDueling=false
    duelActiveTab.Visible=false ; duelChallengeTab.Visible=true ; duelPanel.Visible=false
    local won=(data.winnerName==player.Name)
    duelResultLbl.Text=won and "⚔️ YOU WON! +"..data.sigmaStake.."σ" or "⚔️ YOU LOST! -"..data.sigmaStake.."σ"
    duelResultLbl.TextColor3=won and Color3.fromRGB(100,255,150) or Color3.fromRGB(255,100,100)
    duelResultPopup.Visible=true
    task.delay(3.5, function() duelResultPopup.Visible=false end)
end)

Remotes:WaitForChild("DuelCancel").OnClientEvent:Connect(function(data)
    isDueling=false
    duelActiveTab.Visible=false ; duelChallengeTab.Visible=true
    if data and data.reason=="declined" then
        duelResultLbl.Text="❌ Duel declined"
        duelResultLbl.TextColor3=Color3.fromRGB(200,200,200)
        duelResultPopup.Visible=true
        task.delay(2.5, function() duelResultPopup.Visible=false end)
    end
end)

-- ── Event banner ──────────────────────────────────────────────────────────
local evBanner = Instance.new("Frame")
evBanner.Size=UDim2.new(0,540,0,80) ; evBanner.AnchorPoint=Vector2.new(0.5,0)
evBanner.Position=UDim2.new(0.5,0,0,-100) ; evBanner.BackgroundColor3=Color3.fromRGB(18,18,18)
evBanner.BackgroundTransparency=0.05 ; evBanner.BorderSizePixel=0
evBanner.ZIndex=20 ; evBanner.Parent=screen
corner(evBanner,14)
Instance.new("UIStroke",evBanner).Color=Color3.fromRGB(255,215,0)

local evLabel=lbl({Name="EventLabel",Size=UDim2.new(1,-16,0.6,0),Position=UDim2.new(0,8,0,4),
    Text="",TextColor3=Color3.fromRGB(255,215,0),TextScaled=true,Font=Enum.Font.GothamBold,ZIndex=21},evBanner)
local evSub=lbl({Name="EventSub",Size=UDim2.new(1,-16,0.4,0),Position=UDim2.new(0,8,0.6,-2),
    Text="",TextColor3=Color3.fromRGB(200,200,200),TextScaled=true,Font=Enum.Font.Gotham,ZIndex=21},evBanner)

Remotes:WaitForChild("EventNotify").OnClientEvent:Connect(function(event)
    if event then
        evLabel.Text=event.emoji.."  "..event.name:upper().."!"
        evSub.Text=event.description
        TweenService:Create(evBanner,TweenInfo.new(0.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
            {Position=UDim2.new(0.5,0,0,148)}):Play()
    else
        TweenService:Create(evBanner,TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
            {Position=UDim2.new(0.5,0,0,-100)}):Play()
    end
end)

-- ── Server announce banner ───────────────────────────────────────────────
local annBanner = Instance.new("Frame")
annBanner.Size=UDim2.new(0,580,0,0) ; annBanner.AnchorPoint=Vector2.new(0.5,0.5)
annBanner.Position=UDim2.new(0.5,0,0.5,-200) ; annBanner.BackgroundColor3=Color3.fromRGB(18,0,32)
annBanner.BackgroundTransparency=0.05 ; annBanner.BorderSizePixel=0
annBanner.ZIndex=25 ; annBanner.Visible=false ; annBanner.Parent=screen
corner(annBanner,14)
Instance.new("UIStroke",annBanner).Color=Color3.fromRGB(160,0,255)

local annLabel=lbl({Name="AnnounceLabel",Size=UDim2.new(1,-16,1,0),Position=UDim2.new(0,8,0,0),
    Text="",TextColor3=Color3.fromRGB(255,215,0),TextScaled=true,Font=Enum.Font.GothamBold,ZIndex=26},annBanner)

local ANN_COLORS={gold=Color3.fromRGB(255,215,0),purple=Color3.fromRGB(180,0,255)}
Remotes:WaitForChild("ServerAnnounce").OnClientEvent:Connect(function(data)
    annLabel.Text=data.text
    annLabel.TextColor3=ANN_COLORS[data.color] or ANN_COLORS.gold
    annBanner.Visible=true
    annBanner.Size=UDim2.new(0,580,0,0)
    TweenService:Create(annBanner,TweenInfo.new(0.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
        {Size=UDim2.new(0,580,0,72)}):Play()
    task.delay(4, function()
        TweenService:Create(annBanner,TweenInfo.new(0.3),{Size=UDim2.new(0,580,0,0)}):Play()
        task.wait(0.35) ; annBanner.Visible=false
    end)
end)

-- ── God Mode flash + label ────────────────────────────────────────────────
local godFlash = Instance.new("Frame")
godFlash.Size=UDim2.new(1,0,1,0) ; godFlash.BackgroundColor3=Color3.fromRGB(255,200,0)
godFlash.BackgroundTransparency=1 ; godFlash.ZIndex=35 ; godFlash.Visible=false ; godFlash.Parent=screen

local godLabel=lbl({Name="GodModeLabel",Size=UDim2.new(0,480,0,60),
    AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,200),
    Text="⚡ SIGMA GOD MODE ⚡",TextColor3=Color3.fromRGB(255,210,0),
    TextScaled=true,Font=Enum.Font.GothamBold,ZIndex=36,Visible=false},screen)

Remotes:WaitForChild("GodModeActive").OnClientEvent:Connect(function()
    godFlash.Visible=true ; godFlash.BackgroundTransparency=0.25
    TweenService:Create(godFlash,TweenInfo.new(0.6),{BackgroundTransparency=1}):Play()
    task.delay(0.7, function() godFlash.Visible=false end)
    clickButton.BackgroundColor3=Color3.fromRGB(255,200,0)
    godLabel.Visible=true
    task.spawn(function()
        for i=10,1,-1 do
            if not godLabel.Visible then break end
            godLabel.Text="⚡ GOD MODE ⚡ "..i.."s"
            task.wait(1)
        end
        godLabel.Visible=false
        clickButton.BackgroundColor3=Color3.fromRGB(255,215,0)
    end)
end)
Remotes:WaitForChild("GodModeEnded").OnClientEvent:Connect(function()
    godLabel.Visible=false
    clickButton.BackgroundColor3=Color3.fromRGB(255,215,0)
end)

-- ── Hatch cinematic overlay ───────────────────────────────────────────────
local hatchOverlay = Instance.new("Frame")
hatchOverlay.Name="HatchOverlay" ; hatchOverlay.Size=UDim2.new(1,0,1,0)
hatchOverlay.BackgroundColor3=Color3.fromRGB(0,0,0) ; hatchOverlay.BackgroundTransparency=0.35
hatchOverlay.ZIndex=40 ; hatchOverlay.Visible=false ; hatchOverlay.Parent=screen

-- Egg display
local hatchEggFrame = Instance.new("Frame")
hatchEggFrame.Size=UDim2.new(0,200,0,200) ; hatchEggFrame.AnchorPoint=Vector2.new(0.5,0.5)
hatchEggFrame.Position=UDim2.new(0.5,0,0.35,0) ; hatchEggFrame.BackgroundTransparency=1
hatchEggFrame.ZIndex=41 ; hatchEggFrame.Parent=hatchOverlay

local hatchEggLbl=lbl({Name="HatchEggLbl",Size=UDim2.new(1,0,1,0),
    Text="🥚",TextScaled=true,Font=Enum.Font.GothamBold,ZIndex=42},hatchEggFrame)

-- 3-slot spinner
local spinFrame = Instance.new("Frame")
spinFrame.Size=UDim2.new(0,400,0,110) ; spinFrame.AnchorPoint=Vector2.new(0.5,0.5)
spinFrame.Position=UDim2.new(0.5,0,0.42,0) ; spinFrame.BackgroundColor3=Color3.fromRGB(18,18,18)
spinFrame.BackgroundTransparency=0.05 ; spinFrame.BorderSizePixel=0
spinFrame.ZIndex=41 ; spinFrame.Visible=false ; spinFrame.Parent=hatchOverlay
corner(spinFrame,14)

local slots={}
for i=1,3 do
    local off=(i==1) and 4 or ((i==3) and -4 or 0)
    local s=lbl({Size=UDim2.new(1/3,-8,1,-10),
        Position=UDim2.new((i-1)/3,off+(i==1 and 0 or (i==2 and 0 or 0)),0,5),
        Text="🥚",TextScaled=true,Font=Enum.Font.GothamBold,ZIndex=42,
        TextColor3=Color3.fromRGB(255,255,255)},spinFrame)
    s.BackgroundColor3=Color3.fromRGB(30,30,30) ; s.BackgroundTransparency=0
    corner(s,8) ; slots[i]=s
end
-- Highlight middle slot
local stroke=Instance.new("UIStroke") ; stroke.Color=Color3.fromRGB(255,215,0) ; stroke.Thickness=3 ; stroke.Parent=slots[2]

-- Result frame
local resultFrame = Instance.new("Frame")
resultFrame.Size=UDim2.new(0,360,0,220) ; resultFrame.AnchorPoint=Vector2.new(0.5,0.5)
resultFrame.Position=UDim2.new(0.5,0,0.5,0) ; resultFrame.BackgroundColor3=Color3.fromRGB(14,14,14)
resultFrame.BackgroundTransparency=0.05 ; resultFrame.BorderSizePixel=0
resultFrame.ZIndex=41 ; resultFrame.Visible=false ; resultFrame.Parent=hatchOverlay
corner(resultFrame,16)

local resPetEmoji=lbl({Size=UDim2.new(1,0,0,80),Text="🐶",TextScaled=true,Font=Enum.Font.GothamBold,ZIndex=42},resultFrame)
local resPetName =lbl({Size=UDim2.new(1,0,0,44),Position=UDim2.new(0,0,0,80),
    Text="NPC Dog",TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.GothamBold,ZIndex=42},resultFrame)
local resRarity  =lbl({Size=UDim2.new(1,0,0,36),Position=UDim2.new(0,0,0,124),
    Text="Common",TextColor3=Color3.fromRGB(190,190,190),TextScaled=true,Font=Enum.Font.Gotham,ZIndex=42},resultFrame)
local resDup     =lbl({Size=UDim2.new(1,0,0,32),Position=UDim2.new(0,0,0,160),
    Text="",TextColor3=Color3.fromRGB(150,255,150),TextScaled=true,Font=Enum.Font.Gotham,ZIndex=42},resultFrame)

local continueBtn=btn({Size=UDim2.new(0,180,0,52),AnchorPoint=Vector2.new(0.5,0),
    Position=UDim2.new(0.5,0,0.72,0),BackgroundColor3=Color3.fromRGB(255,215,0),
    Text="✨ Continue",TextColor3=Color3.fromRGB(0,0,0),TextScaled=true,
    Font=Enum.Font.GothamBold,ZIndex=45,Visible=false},hatchOverlay)
corner(continueBtn,12)
continueBtn.MouseButton1Click:Connect(function() hatchOverlay.Visible=false end)

local hatchPlaying=false
local ALL_EMOJIS={}
for _,p in ipairs(Pets) do table.insert(ALL_EMOJIS,p.emoji) end

local function playHatchCinematic(petDef,isDuplicate,rizzBonus,eggDef)
    if hatchPlaying then return end
    hatchPlaying=true
    hatchOverlay.Visible=true
    spinFrame.Visible=false ; resultFrame.Visible=false ; continueBtn.Visible=false
    hatchEggFrame.Visible=true
    hatchEggLbl.Text=eggDef.emoji
    hatchEggLbl.TextColor3=eggDef.color or Color3.fromRGB(255,255,255)

    -- Shake the egg
    for i=1,7 do
        local ox=(i%2==0) and 14 or -14
        TweenService:Create(hatchEggFrame,TweenInfo.new(0.07),
            {Position=UDim2.new(0.5,ox,0.35,0)}):Play()
        task.wait(0.09)
    end
    hatchEggFrame.Position=UDim2.new(0.5,0,0.35,0)
    hatchEggLbl.Text="💥" ; task.wait(0.3)
    hatchEggFrame.Visible=false ; spinFrame.Visible=true

    -- Spin slots
    local intervals={0.06,0.06,0.06}
    local function spinSlot(idx,stopAfter,finalEmoji)
        local elapsed=0
        while elapsed<stopAfter do
            slots[idx].Text=ALL_EMOJIS[math.random(1,#ALL_EMOJIS)]
            task.wait(intervals[idx])
            elapsed+=intervals[idx]
            if elapsed>stopAfter*0.55 then
                intervals[idx]=math.min(intervals[idx]+0.012,0.28)
            end
        end
        slots[idx].Text=finalEmoji
    end
    local sideA=ALL_EMOJIS[math.random(1,#ALL_EMOJIS)]
    local sideB=ALL_EMOJIS[math.random(1,#ALL_EMOJIS)]
    task.spawn(spinSlot,1,1.6,sideA)
    task.spawn(spinSlot,2,2.5,petDef.emoji)  -- middle slot is result
    task.spawn(spinSlot,3,1.9,sideB)
    task.wait(2.7)

    -- Show result
    spinFrame.Visible=false ; resultFrame.Visible=true
    resultFrame.Size=UDim2.new(0,0,0,0)
    resPetEmoji.Text=petDef.emoji ; resPetName.Text=petDef.name
    resRarity.Text="✦ "..petDef.rarity.." ✦"
    resRarity.TextColor3=RARITY_COLORS[petDef.rarity] or Color3.fromRGB(190,190,190)
    if isDuplicate then
        resDup.Text="DUPLICATE! 💎 +"..rizzBonus.." Rizz returned"
        resDup.TextColor3=Color3.fromRGB(200,150,255)
    else
        resDup.Text="🎉 NEW PET!" ; resDup.TextColor3=Color3.fromRGB(255,215,0)
    end
    TweenService:Create(resultFrame,TweenInfo.new(0.45,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
        {Size=UDim2.new(0,360,0,220)}):Play()
    task.wait(0.55) ; continueBtn.Visible=true
    hatchPlaying=false
end

Remotes:WaitForChild("HatchResult").OnClientEvent:Connect(function(data)
    local eggDef,petDef=nil,nil
    for _,e in ipairs(Eggs) do if e.id==data.eggId then eggDef=e break end end
    for _,p in ipairs(Pets) do if p.id==data.petId then petDef=p break end end
    if eggDef and petDef then
        task.spawn(playHatchCinematic,petDef,data.isDuplicate,data.rizzBonus,eggDef)
    end
end)

-- ── Floating numbers ──────────────────────────────────────────────────────
local CRIT_COLORS={
    ["GIGACHAD!!"]=Color3.fromRGB(255,60,60),
    ["SIGMA!"]    =Color3.fromRGB(255,140,0),
    ["NICE"]      =Color3.fromRGB(255,215,0),
    [""]          =Color3.fromRGB(255,255,255),
}
local function spawnFloat(gain,critLabel)
    local fl=Instance.new("TextLabel")
    fl.Size=UDim2.new(0,180,0,52) ; fl.AnchorPoint=Vector2.new(0.5,0.5)
    fl.Position=UDim2.new(0.5,math.random(-80,80),1,-295)
    fl.BackgroundTransparency=1
    fl.TextColor3=CRIT_COLORS[critLabel] or Color3.fromRGB(255,255,255)
    fl.TextScaled=true ; fl.Font=Enum.Font.GothamBold ; fl.ZIndex=10
    fl.Text=critLabel~="" and (critLabel.."! +"..gain.."σ") or ("+"..gain.."σ")
    fl.Parent=screen
    TweenService:Create(fl,TweenInfo.new(0.75,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
        {Position=UDim2.new(0.5,math.random(-80,80),1,-400),TextTransparency=1}):Play()
    task.delay(0.85, function() fl:Destroy() end)
end

-- ── UpdateUI handler ──────────────────────────────────────────────────────
Remotes:WaitForChild("UpdateUI").OnClientEvent:Connect(function(data)
    sigmaLabel.Text="😎  "..tostring(data.sigma).." σ"
    petIncomeLabel.Text="🐾 "..tostring(data.petIncome).." σ/sec"
    multLabel.Text="x"..tostring(data.multiplier).." per click"
    rizzLabel.Text="💎  "..tostring(data.rizzTokens).." Rizz"
    rankLabel.Text=data.rank.emoji.."  "..data.rank.name

    if data.nextRank then
        local prev=data.rank.sigmaRequired ; local nxt=data.nextRank.sigmaRequired
        local pct=math.clamp((data.sigma-prev)/(nxt-prev),0,1)
        TweenService:Create(progBar,TweenInfo.new(0.2),{Size=UDim2.new(pct,0,1,0)}):Play()
    else
        progBar.Size=UDim2.new(1,0,1,0)
    end

    -- Prestige button
    local canP=data.sigma>=data.prestThresh
    prestigeBtn.Visible=canP
    if canP then
        prestigeBtn.Text="🌌 PRESTIGE #"..(data.prestige+1)
        prestigeBtn.BackgroundColor3=Color3.fromRGB(120,0,180)
    end

    -- Floating number
    if data.lastGain and data.lastGain>0 then
        spawnFloat(data.lastGain,data.critLabel or "")
    end

    -- Upgrade affordability
    for _,u in ipairs(Upgrades) do
        local b=upgradeButtons[u.id]
        if b then
            local can=data.sigma>=u.cost
            b.BackgroundColor3=can and Color3.fromRGB(32,32,32) or Color3.fromRGB(20,20,20)
            b.TextColor3=can and Color3.fromRGB(255,255,255) or Color3.fromRGB(100,100,100)
        end
    end

    -- Rebuild My Pets tab
    rebuildMyPets(data.ownedPets, data.equippedPets)
end)

-- ── Co-op boost ───────────────────────────────────────────────────────────
Remotes:WaitForChild("CoopBoost").OnClientEvent:Connect(function(active)
    coopLabel.Visible=active
    coopLabel.Text=active and "👥 Co-op Boost +20%!" or ""
end)

-- ── Leaderboard update ────────────────────────────────────────────────────
local MEDALS={"🥇","🥈","🥉","4️⃣","5️⃣"}
Remotes:WaitForChild("LeaderboardUpdate").OnClientEvent:Connect(function(top5)
    for i,row in ipairs(boardRows) do
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
