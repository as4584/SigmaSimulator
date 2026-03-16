-- GameManager.server.lua  (V3)
-- ALL server logic: clicks, upgrades, prestige+speed, pets (hatch/equip/exchange),
-- DataStore V3, God Mode, Duels, Wandering NPCs, Events, Co-op boost, Leaderboard

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")
local Workspace         = game:GetService("Workspace")

local Ranks   = require(ReplicatedStorage:WaitForChild("Ranks"))
local Upgrades= require(ReplicatedStorage:WaitForChild("Upgrades"))
local Pets    = require(ReplicatedStorage:WaitForChild("Pets"))
local Events  = require(ReplicatedStorage:WaitForChild("Events"))
local Eggs    = require(ReplicatedStorage:WaitForChild("Eggs"))

-- Pre-build pet lookup maps
local petIncomeMap  = {}
local petDefById    = {}
local PET_BY_RARITY = {}
for _, pet in ipairs(Pets) do
    petIncomeMap[pet.id]  = pet.sigmaPerSec
    petDefById[pet.id]    = pet
    PET_BY_RARITY[pet.rarity] = PET_BY_RARITY[pet.rarity] or {}
    table.insert(PET_BY_RARITY[pet.rarity], pet)
end

local eggDefById = {}
for _, e in ipairs(Eggs) do eggDefById[e.id] = e end

-- ── RemoteEvents ──────────────────────────────────────────────────────────
local Remotes = Instance.new("Folder")
Remotes.Name   = "Remotes"
Remotes.Parent = ReplicatedStorage

local function remote(name)
    local e = Instance.new("RemoteEvent")
    e.Name = name ; e.Parent = Remotes ; return e
end

-- Core
local ClickEvent          = remote("ClickSigma")
local BuyUpgradeEvent     = remote("BuyUpgrade")
local UpdateUIEvent       = remote("UpdateUI")
local ComboActiveEvent    = remote("ComboActive")
local ComboEndedEvent     = remote("ComboEnded")
local EventNotifyEvent    = remote("EventNotify")
local PrestigeEvent       = remote("Prestige")
local ServerAnnounceEvent = remote("ServerAnnounce")
-- Pets / Eggs
local HatchEggEvent       = remote("HatchEgg")
local HatchResultEvent    = remote("HatchResult")
local EquipPetEvent       = remote("EquipPet")
local ExchangePetEvent    = remote("ExchangePet")
-- God Mode
local GodModeActiveEvent  = remote("GodModeActive")
local GodModeEndedEvent   = remote("GodModeEnded")
-- Social
local LeaderboardUpdateEvent = remote("LeaderboardUpdate")
local CoopBoostEvent         = remote("CoopBoost")
local OnlinePlayersEvent     = remote("OnlinePlayers")
-- Duel
local DuelChallengeEvent  = remote("DuelChallenge")
local DuelInviteEvent     = remote("DuelInvite")
local DuelAcceptEvent     = remote("DuelAccept")
local DuelDeclineEvent    = remote("DuelDecline")
local DuelStartEvent      = remote("DuelStart")
local DuelClickEvent      = remote("DuelClick")
local DuelUpdateEvent     = remote("DuelUpdate")
local DuelResultEvent     = remote("DuelResult")
local DuelCancelEvent     = remote("DuelCancel")

-- Shared event multiplier value
local evMult = Instance.new("NumberValue")
evMult.Name   = "EventMultiplier"
evMult.Value  = 1
evMult.Parent = ReplicatedStorage

-- ── DataStore V3 ──────────────────────────────────────────────────────────
local store = DataStoreService:GetDataStore("SigmaSimV3")

local PRESTIGE_THRESH  = 10000          -- change to 25000000 for production
local PRESTIGE_BONUSES = {1,2,5,10,25,100}
local BASE_SPEED       = 16
local SPEED_PER_PREST  = 5

-- Rizz awarded for hatching a duplicate
local DUP_RIZZ = { Common=3, Rare=8, Legendary=20 }

local function newData()
    return {
        sigma=0, baseMulti=1, owned={}, prestige=0,
        pets={1}, ownedPets={["1"]=1}, rizzTokens=0,
    }
end

local function loadData(uid)
    local ok, res = pcall(function() return store:GetAsync(tostring(uid)) end)
    if ok and type(res)=="table" then
        local d = newData()
        for k in pairs(d) do if res[k]~=nil then d[k]=res[k] end end
        return d
    end
    return newData()
end

local function saveData(uid, d)
    local payload = {
        sigma=d.sigma, baseMulti=d.baseMulti, owned=d.owned,
        prestige=d.prestige, pets=d.pets,
        ownedPets=d.ownedPets, rizzTokens=d.rizzTokens,
    }
    local ok, err = pcall(function()
        store:UpdateAsync(tostring(uid), function() return payload end)
    end)
    if not ok then warn("[GM] saveData failed:", err) end
end

-- ── In-memory state ────────────────────────────────────────────────────────
local pData       = {}
local combos      = {}
local lastRanks   = {}
local godClickTimes = {}  -- UserId → {timestamps}
local godModeActive = {}  -- UserId → bool
local duels       = {}    -- UserId → {opponentId, clicks, active}
local duelPend    = {}    -- targetUserId → {challengerUid, expireAt}
local coopActive  = false

-- ── Helpers ────────────────────────────────────────────────────────────────
local function prestigeBonus(p)
    return PRESTIGE_BONUSES[math.min(p+1, #PRESTIGE_BONUSES)]
end
local function effectiveMulti(d)
    return d.baseMulti * prestigeBonus(d.prestige) * (coopActive and 1.2 or 1)
end
local function petIncome(d)
    local t=0
    for _, id in ipairs(d.pets or {}) do t += (petIncomeMap[id] or 0) end
    return t
end
local CRITS = {
    {label="GIGACHAD!!", mult=20, w=2},
    {label="SIGMA!",     mult=5,  w=8},
    {label="NICE",       mult=2,  w=20},
    {label="",           mult=1,  w=70},
}
local function rollCrit()
    local r,c = math.random(1,100),0
    for _, cr in ipairs(CRITS) do
        c+=cr.w ; if r<=c then return cr end
    end
    return CRITS[#CRITS]
end
local function rankFor(sigma)
    local cur=Ranks[1]
    for _,r in ipairs(Ranks) do
        if not r.prestige and sigma>=r.sigmaRequired then cur=r end
    end
    return cur
end
local function nextRankFor(sigma)
    for _,r in ipairs(Ranks) do
        if not r.prestige and sigma<r.sigmaRequired then return r end
    end
    return nil
end
local function getPlayerById(uid)
    for _,p in ipairs(Players:GetPlayers()) do
        if p.UserId==uid then return p end
    end
    return nil
end

-- ── Rank label above head (visible to everyone) ────────────────────────────
local function applyRankLabel(player, rank)
    local char=player.Character ; if not char then return end
    local head=char:FindFirstChild("Head") ; if not head then return end
    local old=head:FindFirstChild("RankBillboard") ; if old then old:Destroy() end
    local bb=Instance.new("BillboardGui")
    bb.Name="RankBillboard" ; bb.Size=UDim2.new(0,220,0,38)
    bb.StudsOffset=Vector3.new(0,1.8,0) ; bb.AlwaysOnTop=true ; bb.Parent=head
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,0,1,0) ; lbl.BackgroundTransparency=1
    lbl.Text=rank.emoji.."  "..rank.name
    lbl.TextColor3=Color3.fromRGB(255,255,255) ; lbl.TextScaled=true
    lbl.Font=Enum.Font.GothamBold ; lbl.Parent=bb
    local stroke=Instance.new("UIStroke")
    stroke.Color=Color3.fromRGB(0,0,0) ; stroke.Thickness=2 ; stroke.Parent=lbl
end

-- ── Prestige badge ────────────────────────────────────────────────────────
local function applyPrestigeBadge(player)
    local d=pData[player.UserId]
    if not d or d.prestige<=0 then return end
    local char=player.Character
    if not char then return end
    local head=char:FindFirstChild("Head")
    if not head then return end
    local old=head:FindFirstChild("PrestigeBadge")
    if old then old:Destroy() end
    local bb=Instance.new("BillboardGui")
    bb.Name="PrestigeBadge" ; bb.Size=UDim2.new(0,140,0,32)
    bb.StudsOffset=Vector3.new(0,3,0) ; bb.AlwaysOnTop=true ; bb.Parent=head
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,0,1,0) ; lbl.BackgroundTransparency=1
    lbl.Text="⭐ PRESTIGE "..d.prestige
    lbl.TextColor3=Color3.fromRGB(255,215,0) ; lbl.TextScaled=true
    lbl.Font=Enum.Font.GothamBold ; lbl.Parent=bb
end

-- ── Prestige speed ────────────────────────────────────────────────────────
local function applySpeed(player)
    local d=pData[player.UserId]
    if not d then return end
    local char=player.Character
    if not char then return end
    local hum=char:FindFirstChild("Humanoid")
    if hum then hum.WalkSpeed = BASE_SPEED + d.prestige * SPEED_PER_PREST end
end

-- ── Sync to client ────────────────────────────────────────────────────────
local function sync(player, gain, label)
    local d=pData[player.UserId]
    if not d then return end
    local rank=rankFor(d.sigma)
    local nxt=nextRankFor(d.sigma)
    local old=lastRanks[player.UserId]
    if old and old~=rank.name then
        d.rizzTokens+=10
        ServerAnnounceEvent:FireAllClients({
            text=player.Name.." ranked up to "..rank.emoji.." "..rank.name.."! +10💎",
            color="gold",
        })
        applyRankLabel(player, rank)
    end
    lastRanks[player.UserId]=rank.name
    player.leaderstats.Sigma.Value    = d.sigma
    player.leaderstats.Rank.Value     = rank.emoji.." "..rank.name
    player.leaderstats.Prestige.Value = d.prestige
    UpdateUIEvent:FireClient(player, {
        sigma        = d.sigma,
        multiplier   = effectiveMulti(d),
        petIncome    = petIncome(d),
        prestige     = d.prestige,
        prestThresh  = PRESTIGE_THRESH,
        rank         = rank,
        nextRank     = nxt,
        lastGain     = gain  or 0,
        critLabel    = label or "",
        rizzTokens   = d.rizzTokens,
        ownedPets    = d.ownedPets,
        equippedPets = d.pets,
        coopBoost    = coopActive,
    })
end

-- ── Player lifecycle ──────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
    local ls=Instance.new("Folder")
    ls.Name="leaderstats" ; ls.Parent=player
    local function val(cls,name,def)
        local v=Instance.new(cls); v.Name=name; v.Value=def; v.Parent=ls; return v
    end
    val("IntValue","Sigma",0)
    val("StringValue","Rank","🤡 NPC")
    val("IntValue","Prestige",0)
    local d=loadData(player.UserId)
    -- Rebuild baseMulti from owned upgrades
    d.baseMulti=1
    for key,owned in pairs(d.owned) do
        if owned then
            local id=tonumber(key)
            for _,u in ipairs(Upgrades) do
                if u.id==id and u.effect=="click_multiplier" then
                    d.baseMulti *= u.value
                end
            end
        end
    end
    pData[player.UserId]     = d
    lastRanks[player.UserId] = rankFor(d.sigma).name
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        applyPrestigeBadge(player)
        applySpeed(player)
        applyRankLabel(player, rankFor(pData[player.UserId] and pData[player.UserId].sigma or 0))
    end)
    task.wait(1)
    sync(player,0,"")
end)

Players.PlayerRemoving:Connect(function(player)
    -- Duel cleanup
    local dState=duels[player.UserId]
    if dState then
        local opp=getPlayerById(dState.opponentId)
        if opp then DuelCancelEvent:FireClient(opp,{reason="opponent_left"}) end
        duels[dState.opponentId]=nil
        duels[player.UserId]=nil
    end
    for uid,pend in pairs(duelPend) do
        if uid==player.UserId or pend.challengerUid==player.UserId then
            duelPend[uid]=nil
        end
    end
    -- Save
    local d=pData[player.UserId]
    if d then saveData(player.UserId,d) end
    pData[player.UserId]=nil
    combos[player.UserId]=nil
    lastRanks[player.UserId]=nil
    godClickTimes[player.UserId]=nil
    godModeActive[player.UserId]=nil
end)

game:BindToClose(function()
    for _,p in ipairs(Players:GetPlayers()) do
        local d=pData[p.UserId]
        if d then saveData(p.UserId,d) end
    end
    task.wait(2)
end)

-- Auto-save every 60s
task.spawn(function()
    while true do
        task.wait(60)
        for _,p in ipairs(Players:GetPlayers()) do
            local d=pData[p.UserId]
            if d then saveData(p.UserId,d) end
        end
    end
end)

-- Pet income tick
task.spawn(function()
    while true do
        task.wait(1)
        for _,p in ipairs(Players:GetPlayers()) do
            local d=pData[p.UserId]
            if d then
                local inc=petIncome(d)
                if inc>0 then d.sigma+=inc ; sync(p,0,"") end
            end
        end
    end
end)

-- ── Click (with God Mode detection) ──────────────────────────────────────
local GOD_CLICKS   = 20
local GOD_WINDOW   = 5
local GOD_DURATION = 10
local GOD_MULT     = 100

ClickEvent.OnServerEvent:Connect(function(player)
    local d=pData[player.UserId]
    if not d then return end
    local uid=player.UserId
    -- God Mode tracking
    godClickTimes[uid]=godClickTimes[uid] or {}
    local t=os.clock()
    table.insert(godClickTimes[uid],t)
    local cut=t-GOD_WINDOW
    while godClickTimes[uid][1] and godClickTimes[uid][1]<cut do
        table.remove(godClickTimes[uid],1)
    end
    if #godClickTimes[uid]>=GOD_CLICKS and not godModeActive[uid] then
        godModeActive[uid]=true
        GodModeActiveEvent:FireClient(player)
        ServerAnnounceEvent:FireAllClients({
            text="⚡ "..player.Name.." entered SIGMA GOD MODE!",
            color="gold",
        })
        task.delay(GOD_DURATION, function()
            godModeActive[uid]=false
            godClickTimes[uid]={}
            GodModeEndedEvent:FireClient(player)
        end)
    end
    local cr   = rollCrit()
    local godB = godModeActive[uid] and GOD_MULT or 1
    local gain = math.max(1, math.floor(
        effectiveMulti(d) * cr.mult * evMult.Value *
        (combos[uid] and 1.5 or 1) * godB
    ))
    d.sigma+=gain
    sync(player,gain,cr.label)
end)

ComboActiveEvent.OnServerEvent:Connect(function(p) combos[p.UserId]=true  end)
ComboEndedEvent.OnServerEvent:Connect(function(p)  combos[p.UserId]=false end)

-- ── Upgrade purchase ──────────────────────────────────────────────────────
BuyUpgradeEvent.OnServerEvent:Connect(function(player, upgradeId)
    local d=pData[player.UserId]
    if not d then return end
    local u=nil
    for _,up in ipairs(Upgrades) do if up.id==upgradeId then u=up break end end
    if not u then return end
    if d.owned[tostring(u.id)] then return end
    if d.sigma < u.cost then return end
    d.sigma -= u.cost
    d.owned[tostring(u.id)]=true
    if u.effect=="click_multiplier" then d.baseMulti *= u.value end
    sync(player,0,"")
end)

-- ── Prestige (resest + permanent bonus + speed + badge) ───────────────────
PrestigeEvent.OnServerEvent:Connect(function(player)
    local d=pData[player.UserId]
    if not d or d.sigma < PRESTIGE_THRESH then return end
    d.prestige+=1 ; d.sigma=0 ; d.baseMulti=1 ; d.owned={}
    saveData(player.UserId,d)
    ServerAnnounceEvent:FireAllClients({
        text="⭐ "..player.Name.." PRESTIGED! Prestige "..d.prestige
             .."  ("..prestigeBonus(d.prestige).."x permanent bonus)",
        color="purple",
    })
    applyPrestigeBadge(player)
    applySpeed(player)
    sync(player,0,"")
end)

-- ── Egg hatching ──────────────────────────────────────────────────────────
local function rollEgg(eggDef)
    local r=math.random(1,100)
    local rarity
    if     r <= eggDef.weights.Legendary then rarity="Legendary"
    elseif r <= eggDef.weights.Legendary + eggDef.weights.Rare then rarity="Rare"
    else   rarity="Common" end
    local pool=PET_BY_RARITY[rarity] or PET_BY_RARITY["Common"]
    return pool[math.random(1,#pool)]
end

HatchEggEvent.OnServerEvent:Connect(function(player, eggId)
    local d=pData[player.UserId]
    if not d then return end
    local eggDef=eggDefById[eggId]
    if not eggDef then return end
    if d.rizzTokens < eggDef.cost then return end
    d.rizzTokens -= eggDef.cost
    local petDef=rollEgg(eggDef)
    local key=tostring(petDef.id)
    d.ownedPets=d.ownedPets or {}
    local isDuplicate=(d.ownedPets[key] or 0)>0
    d.ownedPets[key]=(d.ownedPets[key] or 0)+1
    local rizzBonus=0
    if isDuplicate then
        rizzBonus=DUP_RIZZ[petDef.rarity] or 3
        d.rizzTokens+=rizzBonus
    end
    HatchResultEvent:FireClient(player,{
        petId=petDef.id, eggId=eggId,
        isDuplicate=isDuplicate, rizzBonus=rizzBonus,
    })
    sync(player,0,"")
end)

-- ── Exchange pet duplicate for Rizz ──────────────────────────────────────
ExchangePetEvent.OnServerEvent:Connect(function(player, petId)
    local d=pData[player.UserId]
    if not d then return end
    local key=tostring(petId)
    if not d.ownedPets[key] or d.ownedPets[key]<2 then return end
    d.ownedPets[key]-=1
    local petDef=petDefById[petId]
    local gain=petDef and (DUP_RIZZ[petDef.rarity] or 3) or 3
    d.rizzTokens+=gain
    sync(player,0,"")
end)

-- ── Equip / Unequip pet ───────────────────────────────────────────────────
EquipPetEvent.OnServerEvent:Connect(function(player, petId)
    local d=pData[player.UserId]
    if not d then return end
    local key=tostring(petId)
    if not d.ownedPets[key] or d.ownedPets[key]<1 then return end
    for i,id in ipairs(d.pets) do
        if id==petId then
            table.remove(d.pets,i)
            sync(player,0,"")
            return
        end
    end
    if #d.pets>=3 then table.remove(d.pets,1) end
    table.insert(d.pets,petId)
    sync(player,0,"")
end)

-- ── Co-op boost monitor ───────────────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(5)
        local active=#Players:GetPlayers()>=2
        if active~=coopActive then
            coopActive=active
            for _,p in ipairs(Players:GetPlayers()) do
                CoopBoostEvent:FireClient(p,active)
            end
        end
    end
end)

-- ── Leaderboard broadcaster ───────────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(10)
        local entries={}
        for _,p in ipairs(Players:GetPlayers()) do
            local d=pData[p.UserId]
            if d then
                table.insert(entries,{name=p.Name,sigma=d.sigma,prestige=d.prestige})
            end
        end
        table.sort(entries,function(a,b) return a.sigma>b.sigma end)
        local top5={}
        for i=1,math.min(5,#entries) do top5[i]=entries[i] end
        for _,p in ipairs(Players:GetPlayers()) do
            LeaderboardUpdateEvent:FireClient(p,top5)
        end
    end
end)

-- ── Online players list (for duel picker) ────────────────────────────────
task.spawn(function()
    while true do
        task.wait(5)
        local names={}
        for _,p in ipairs(Players:GetPlayers()) do table.insert(names,p.Name) end
        for _,p in ipairs(Players:GetPlayers()) do
            OnlinePlayersEvent:FireClient(p,names)
        end
    end
end)

-- ── Wandering NPC spawns ──────────────────────────────────────────────────
local MAX_NPCS=5 ; local npcCount=0
local function spawnWanderingNpc()
    if npcCount>=MAX_NPCS then return end
    npcCount+=1
    local part=Instance.new("Part")
    part.Size=Vector3.new(2,3,2)
    part.BrickColor=BrickColor.new("Bright red")
    part.Anchored=true
    part.CFrame=CFrame.new(math.random(-44,44),1.5,math.random(-44,44))
    part.Parent=Workspace
    local bb=Instance.new("BillboardGui")
    bb.Size=UDim2.new(0,120,0,30) ; bb.StudsOffset=Vector3.new(0,2.5,0)
    bb.AlwaysOnTop=true ; bb.Parent=part
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,0,1,0) ; lbl.BackgroundTransparency=1
    lbl.Text="😡 NPC  +30σ" ; lbl.TextColor3=Color3.fromRGB(255,100,100)
    lbl.TextScaled=true ; lbl.Font=Enum.Font.GothamBold ; lbl.Parent=bb
    local cd=Instance.new("ClickDetector")
    cd.MaxActivationDistance=25 ; cd.Parent=part
    cd.MouseClick:Connect(function(player)
        local d=pData[player.UserId]
        if not d then return end
        d.sigma+=30 ; sync(player,30,"NICE")
        npcCount-=1 ; part:Destroy()
    end)
    -- Simple wander
    task.spawn(function()
        local lifetime=math.random(12,25)
        local elapsed=0
        while elapsed<lifetime and part.Parent do
            local tx=math.random(-44,44) ; local tz=math.random(-44,44)
            local dist=math.sqrt((tx-part.Position.X)^2+(tz-part.Position.Z)^2)
            local dur=math.max(dist/7,0.5)
            local sx,sz=part.Position.X,part.Position.Z
            local t2=0
            while t2<dur and part.Parent do
                task.wait(0.15) ; t2+=0.15
                local f=math.min(t2/dur,1)
                part.CFrame=CFrame.new(sx+(tx-sx)*f, 1.5, sz+(tz-sz)*f)
            end
            elapsed+=dur ; task.wait(0.5) ; elapsed+=0.5
        end
        if part and part.Parent then npcCount-=1 ; part:Destroy() end
    end)
end
task.spawn(function()
    while true do task.wait(12) ; spawnWanderingNpc() end
end)

-- ── Event system ──────────────────────────────────────────────────────────
local function makePart(cf,size,colorName,label)
    local part=Instance.new("Part")
    part.Size=size ; part.CFrame=cf ; part.Anchored=true
    part.BrickColor=BrickColor.new(colorName) ; part.Parent=Workspace
    if label then
        local bb=Instance.new("BillboardGui")
        bb.Size=UDim2.new(0,160,0,40) ; bb.StudsOffset=Vector3.new(0,size.Y/2+2,0)
        bb.AlwaysOnTop=true ; bb.Parent=part
        local lbl=Instance.new("TextLabel")
        lbl.Size=UDim2.new(1,0,1,0) ; lbl.BackgroundTransparency=1
        lbl.Text=label ; lbl.TextColor3=Color3.fromRGB(255,215,0)
        lbl.TextScaled=true ; lbl.Font=Enum.Font.GothamBold ; lbl.Parent=bb
    end
    local cd=Instance.new("ClickDetector") ; cd.MaxActivationDistance=50 ; cd.Parent=part
    return part,cd
end
local function rndCF()
    return CFrame.new(math.random(-50,50),3,math.random(-50,50))
end
local function runEvent(event)
    for _,p in ipairs(Players:GetPlayers()) do EventNotifyEvent:FireClient(p,event) end
    local cleanup={}
    if event.effect=="sigma_multiplier" then
        evMult.Value=event.value
        table.insert(cleanup,function() evMult.Value=1 end)
    elseif event.effect=="rizz_tokens" then
        local coins={}
        for _=1,8 do
            -- Unanchored coin falls from sky like actual rain
            local coin=Instance.new("Part")
            coin.Size=Vector3.new(2.5,2.5,2.5)
            coin.Shape=Enum.PartType.Ball
            coin.BrickColor=BrickColor.new("Bright yellow")
            coin.Material=Enum.Material.Neon
            coin.CFrame=CFrame.new(math.random(-50,50), math.random(25,50), math.random(-50,50))
            coin.Anchored=false
            coin.Parent=Workspace
            -- Billboard label
            local bb=Instance.new("BillboardGui")
            bb.Size=UDim2.new(0,120,0,32) ; bb.StudsOffset=Vector3.new(0,2.5,0)
            bb.AlwaysOnTop=true ; bb.Parent=coin
            local lbl=Instance.new("TextLabel")
            lbl.Size=UDim2.new(1,0,1,0) ; lbl.BackgroundTransparency=1
            lbl.Text="💎 +"..event.value.." Rizz!"
            lbl.TextColor3=Color3.fromRGB(255,215,0) ; lbl.TextScaled=true
            lbl.Font=Enum.Font.GothamBold ; lbl.Parent=bb
            table.insert(coins,coin)
            -- Auto-collect on touch — debounced
            local collected=false
            coin.Touched:Connect(function(hit)
                if collected then return end
                local hitPlayer=Players:GetPlayerFromCharacter(hit.Parent)
                if not hitPlayer then return end
                local d=pData[hitPlayer.UserId] ; if not d then return end
                collected=true
                d.rizzTokens+=event.value ; sync(hitPlayer,0,"")
                coin:Destroy()
            end)
        end
        table.insert(cleanup,function()
            for _,c in ipairs(coins) do if c and c.Parent then c:Destroy() end end
        end)
    elseif event.effect=="bonus_clicks" then
        local part,cd=makePart(CFrame.new(0,6,0),Vector3.new(6,10,6),"Bright orange","👑 GIGACHAD! +500σ")
        local claimed={}
        table.insert(cleanup,function() if part and part.Parent then part:Destroy() end end)
        cd.MouseClick:Connect(function(player)
            if claimed[player.UserId] then return end
            claimed[player.UserId]=true
            local d=pData[player.UserId] ; if not d then return end
            d.sigma+=event.value ; sync(player,event.value,"GIGACHAD!!")
        end)
    elseif event.effect=="npc_targets" then
        local npcs={}
        for _=1,10 do
            local part,cd=makePart(rndCF(),Vector3.new(3,4,3),"Bright red","☠️ NPC! +100σ")
            table.insert(npcs,part)
            cd.MouseClick:Connect(function(player)
                local d=pData[player.UserId] ; if not d then return end
                d.sigma+=100 ; sync(player,100,"SIGMA!") ; part:Destroy()
            end)
        end
        table.insert(cleanup,function()
            for _,n in ipairs(npcs) do if n and n.Parent then n:Destroy() end end
        end)
    elseif event.effect=="lottery_jackpot" then
        local orb,cd=makePart(CFrame.new(0,7,0),Vector3.new(5,5,5),"Cyan","🎰 JACKPOT! +"..event.value.."σ — First click wins!")
        orb.Shape=Enum.PartType.Ball ; orb.Material=Enum.Material.Neon
        local won=false
        table.insert(cleanup,function() if orb and orb.Parent then orb:Destroy() end end)
        cd.MouseClick:Connect(function(player)
            if won then return end ; won=true
            local d=pData[player.UserId] ; if not d then return end
            d.sigma+=event.value ; sync(player,event.value,"GIGACHAD!!")
            ServerAnnounceEvent:FireAllClients({
                text="🎰 "..player.Name.." won the Sigma Lottery! +"..event.value.."σ!",
                color="gold",
            })
            orb:Destroy()
        end)
    end
    task.wait(event.duration)
    for _,fn in ipairs(cleanup) do fn() end
    for _,p in ipairs(Players:GetPlayers()) do EventNotifyEvent:FireClient(p,nil) end
end

task.spawn(function()
    task.wait(15)
    while true do
        local event=Events[math.random(1,#Events)]
        runEvent(event)
        task.wait(math.random(30,60))
    end
end)

-- ── Duel system ───────────────────────────────────────────────────────────
DuelChallengeEvent.OnServerEvent:Connect(function(challenger, targetName)
    local target=nil
    for _,p in ipairs(Players:GetPlayers()) do
        if p.Name==targetName then target=p break end
    end
    if not target or target==challenger then return end
    if duels[challenger.UserId] or duels[target.UserId] then return end
    if duelPend[target.UserId] then return end
    duelPend[target.UserId]={challengerUid=challenger.UserId, expireAt=os.clock()+15}
    DuelInviteEvent:FireClient(target,{challengerName=challenger.Name})
    task.delay(15,function()
        local pend=duelPend[target.UserId]
        if pend and pend.challengerUid==challenger.UserId then
            duelPend[target.UserId]=nil
        end
    end)
end)

DuelAcceptEvent.OnServerEvent:Connect(function(target)
    local pend=duelPend[target.UserId]
    if not pend or os.clock()>pend.expireAt then return end
    local challenger=getPlayerById(pend.challengerUid)
    if not challenger then duelPend[target.UserId]=nil ; return end
    duelPend[target.UserId]=nil
    duels[challenger.UserId]={opponentId=target.UserId, clicks=0, active=true}
    duels[target.UserId]    ={opponentId=challenger.UserId, clicks=0, active=true}
    DuelStartEvent:FireClient(challenger,{opponentName=target.Name})
    DuelStartEvent:FireClient(target,{opponentName=challenger.Name})
    task.spawn(function()
        for remaining=30,1,-1 do
            task.wait(1)
            local cS=duels[challenger.UserId]
            local tS=duels[target.UserId]
            if not cS or not tS then return end
            DuelUpdateEvent:FireClient(challenger,{myClicks=cS.clicks,theirClicks=tS.clicks,timeLeft=remaining-1})
            DuelUpdateEvent:FireClient(target,   {myClicks=tS.clicks,theirClicks=cS.clicks,timeLeft=remaining-1})
        end
        local cS=duels[challenger.UserId] ; local tS=duels[target.UserId]
        if not cS or not tS then return end
        local winner,loser
        if (cS.clicks or 0)>=(tS.clicks or 0) then winner=challenger ; loser=target
        else winner=target ; loser=challenger end
        local STAKE=50
        local ld=pData[loser.UserId] ; local wd=pData[winner.UserId]
        if ld and wd then
            local actual=math.min(STAKE,ld.sigma)
            ld.sigma=math.max(0,ld.sigma-actual)
            wd.sigma+=actual
            sync(winner,actual,"SIGMA!")
            sync(loser,0,"")
        end
        DuelResultEvent:FireClient(challenger,{winnerName=winner.Name,sigmaStake=STAKE})
        DuelResultEvent:FireClient(target,    {winnerName=winner.Name,sigmaStake=STAKE})
        ServerAnnounceEvent:FireAllClients({
            text="⚔️ "..winner.Name.." defeated "..loser.Name.." in a Sigma Duel!",
            color="gold",
        })
        duels[challenger.UserId]=nil ; duels[target.UserId]=nil
    end)
end)

DuelDeclineEvent.OnServerEvent:Connect(function(target)
    local pend=duelPend[target.UserId]
    if not pend then return end
    local challenger=getPlayerById(pend.challengerUid)
    duelPend[target.UserId]=nil
    if challenger then DuelCancelEvent:FireClient(challenger,{reason="declined"}) end
end)

DuelClickEvent.OnServerEvent:Connect(function(player)
    local s=duels[player.UserId]
    if s and s.active then s.clicks+=1 end
end)
