-- GameManager.server.lua  (V4)
-- ALL server logic: clicks, upgrades, prestige, ascension, pets (hatch/equip/evolve/exchange),
-- DataStore V4, God Mode, Duels, Wandering NPCs, Events, Co-op boost, Leaderboard,
-- Offline Earnings, Rizz Spin Wheel, Daily Rewards, Sigma Quests, Achievements,
-- AFK rewards, Free Rewards menu

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")
local Workspace         = game:GetService("Workspace")

local Ranks        = require(ReplicatedStorage:WaitForChild("Ranks"))
local Upgrades     = require(ReplicatedStorage:WaitForChild("Upgrades"))
local Pets         = require(ReplicatedStorage:WaitForChild("Pets"))
local Events       = require(ReplicatedStorage:WaitForChild("Events"))
local Eggs         = require(ReplicatedStorage:WaitForChild("Eggs"))
local Quests       = require(ReplicatedStorage:WaitForChild("Quests"))
local Achievements = require(ReplicatedStorage:WaitForChild("Achievements"))
local DailyRewards = require(ReplicatedStorage:WaitForChild("DailyRewards"))
local SpinPrizes   = require(ReplicatedStorage:WaitForChild("SpinPrizes"))

-- ── Pet/Egg lookup maps ──────────────────────────────────────────────────
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

-- ── RemoteEvents ─────────────────────────────────────────────────────────
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
local AscendEvent         = remote("Ascend")
local ServerAnnounceEvent = remote("ServerAnnounce")
-- Pets / Eggs
local HatchEggEvent        = remote("HatchEgg")
local HatchResultEvent     = remote("HatchResult")
local RerollEggEvent       = remote("RerollEgg")
local AutoRollToggleEvent  = remote("AutoRollToggle")
local AutoRollStatusEvent  = remote("AutoRollStatus")
local EquipPetEvent        = remote("EquipPet")
local EvolvePetEvent       = remote("EvolvePet")
local EvolvePetResultEvent = remote("EvolvePetResult")
local ExchangePetEvent     = remote("ExchangePet")
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
-- Spin Wheel
local SpinWheelEvent      = remote("SpinWheel")
local SpinResultEvent     = remote("SpinResult")
-- Daily Rewards
local ClaimDailyEvent     = remote("ClaimDaily")
-- Quests & Achievements
local QuestUpdateEvent    = remote("QuestUpdate")
local AchieveUnlockEvent  = remote("AchieveUnlock")
-- Free Rewards
local FreeRewardEvent     = remote("ClaimFreeReward")

-- Auto-roll state: userId → eggId or nil
local autoRollState = {}

-- Shared event multiplier
local evMult = Instance.new("NumberValue")
evMult.Name   = "EventMultiplier"
evMult.Value  = 1
evMult.Parent = ReplicatedStorage

-- ── Constants ─────────────────────────────────────────────────────────────
local PRESTIGE_THRESH    = 10000
local PRESTIGE_BONUSES   = {1, 2, 5, 10, 25, 100}
local BASE_SPEED         = 16
local SPEED_PER_PREST    = 5
local ASCEND_PRESTIGE    = 5
local OFFLINE_CAP_SECS   = 4 * 3600
local AFK_RIZZ_INTERVAL  = 300
local AFK_RIZZ_AMOUNT    = 15
local SPIN_FREE_COOLDOWN = 6 * 3600
local SPIN_PAID_COST     = 5
local DAILY_COOLDOWN     = 20 * 3600
local DUP_RIZZ           = { Common=3, Rare=8, Legendary=20 }

local FREE_SLOTS = {
    { id="slot1", cooldown=900,   label="15-min",  reward={type="rizz",  amount=10}  },
    { id="slot2", cooldown=3600,  label="1-hour",  reward={type="rizz",  amount=30}  },
    { id="slot3", cooldown=86400, label="24-hour", reward={type="rizz",  amount=100} },
}

local DailyRewardsDef = DailyRewards
local SpinPrizesDef   = SpinPrizes

-- ── DataStore V4 ──────────────────────────────────────────────────────────
local store = DataStoreService:GetDataStore("SigmaSimV4")

local function newData()
    return {
        sigma=0, allTimeSigma=0, baseMulti=1, owned={},
        prestige=0, ascensions=0,
        pets={1}, ownedPets={["1"]=1}, evolvedPets={},
        rizzTokens=0, lastSeen=os.time(),
        questProgress={}, questDone={},
        achievements={},
        dailyStreak=0, lastDailyClaim=0,
        lastSpin=0,
        freeSlotClaimed={},
        totalPlaytime=0, sessionStart=0, lastAfkRizz=0,
        totalClicks=0, totalHatches=0, totalSpins=0, totalEvolutions=0,
    }
end

local function loadData(uid)
    local ok, res = pcall(function() return store:GetAsync(tostring(uid)) end)
    if ok and type(res) == "table" then
        local d = newData()
        for k in pairs(d) do if res[k] ~= nil then d[k] = res[k] end end
        return d
    end
    return newData()
end

local function saveData(uid, d)
    if d.sessionStart and d.sessionStart > 0 then
        local now = os.time()
        d.totalPlaytime = (d.totalPlaytime or 0) + (now - d.sessionStart)
        d.sessionStart  = now
    end
    local payload = {}
    for k, v in pairs(d) do payload[k] = v end
    payload._uid = nil  -- don't persist internal tag
    local ok, err = pcall(function()
        store:UpdateAsync(tostring(uid), function() return payload end)
    end)
    if not ok then warn("[GM] saveData failed:", err) end
end

-- ── In-memory state ───────────────────────────────────────────────────────
local pData         = {}
local combos        = {}
local lastRanks     = {}
local godClickTimes = {}
local godModeActive = {}
local duels         = {}
local duelPend      = {}
local coopActive    = false
local spinBoost     = {}   -- userId → os.clock() expiry

-- ── Helpers ───────────────────────────────────────────────────────────────
local function prestigeBonus(p)
    return PRESTIGE_BONUSES[math.min(p + 1, #PRESTIGE_BONUSES)]
end
local function ascendMulti(d)
    return math.max(1, 2 ^ (d.ascensions or 0))
end
local function effectiveMulti(d)
    local sb  = (spinBoost[d._uid] and os.clock() < spinBoost[d._uid]) and 2 or 1
    return d.baseMulti * prestigeBonus(d.prestige) * ascendMulti(d)
         * (coopActive and 1.2 or 1) * sb
end
local function petIncome(d)
    local t = 0
    for _, id in ipairs(d.pets or {}) do
        local pet = petDefById[id]
        if pet then
            local key = tostring(id)
            if d.evolvedPets and d.evolvedPets[key] then
                t += (pet.evolvedSigmaPerSec or pet.sigmaPerSec * 2)
            else
                t += pet.sigmaPerSec
            end
        end
    end
    return t
end
local CRITS = {
    {label="GIGACHAD!!", mult=20, w=2},
    {label="SIGMA!",     mult=5,  w=8},
    {label="NICE",       mult=2,  w=20},
    {label="",           mult=1,  w=70},
}
local function rollCrit()
    local r, c = math.random(1, 100), 0
    for _, cr in ipairs(CRITS) do c += cr.w ; if r <= c then return cr end end
    return CRITS[#CRITS]
end
local function rankFor(sigma)
    local cur = Ranks[1]
    for _, r in ipairs(Ranks) do
        if not r.prestige and sigma >= r.sigmaRequired then cur = r end
    end
    return cur
end
local function nextRankFor(sigma)
    for _, r in ipairs(Ranks) do
        if not r.prestige and sigma < r.sigmaRequired then return r end
    end
    return nil
end
local function getPlayerById(uid)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.UserId == uid then return p end
    end
    return nil
end

-- ── Quest updater ─────────────────────────────────────────────────────────
local function updateQuest(player, qtype, amount, extra)
    local d = pData[player.UserId] ; if not d then return end
    local changed = false
    for _, q in ipairs(Quests) do
        if d.questDone[q.id] then continue end
        local req   = q.req
        local match = false
        if req.type == "rarity" and qtype == "rarity" then
            match = (req.rarity == extra)
        elseif req.type == qtype and req.type ~= "rarity" then
            match = true
        end
        if match then
            d.questProgress[q.id] = (d.questProgress[q.id] or 0) + amount
            if d.questProgress[q.id] >= (req.amount or 1) then
                d.questDone[q.id] = true
                if q.reward.type == "rizz" then
                    d.rizzTokens += q.reward.amount
                elseif q.reward.type == "sigma" then
                    d.sigma += q.reward.amount ; d.allTimeSigma += q.reward.amount
                end
                ServerAnnounceEvent:FireClient(player, {
                    text  = "✅ Quest: "..q.name.."! +"..q.reward.amount
                           ..(q.reward.type=="rizz" and "💎" or "σ"),
                    color = "gold",
                })
                changed = true
            end
        end
    end
    if changed then
        QuestUpdateEvent:FireClient(player, {
            questProgress=d.questProgress, questDone=d.questDone,
        })
    end
end

-- ── Achievement checker ───────────────────────────────────────────────────
local function checkAchieve(player, triggType, amount, extra)
    local d = pData[player.UserId] ; if not d then return end
    for _, a in ipairs(Achievements) do
        if d.achievements[a.id] then continue end
        local t     = a.trigger
        local match = false
        if t.type == triggType then
            if t.type == "rarity" then
                match = (t.rarity == extra)
            elseif t.type == "all_pets" then
                local all = true
                for _, pet in ipairs(Pets) do
                    if not (d.ownedPets[tostring(pet.id)] and d.ownedPets[tostring(pet.id)] > 0) then
                        all = false ; break
                    end
                end
                match = all
            elseif t.type == "evolution" then
                match = (d.totalEvolutions or 0) >= (t.amount or 1)
            elseif t.amount then
                local val = 0
                if     t.type=="clicks"         then val = d.totalClicks or 0
                elseif t.type=="hatches"         then val = d.totalHatches or 0
                elseif t.type=="prestige"        then val = d.prestige or 0
                elseif t.type=="total_sigma"     then val = d.allTimeSigma or 0
                elseif t.type=="ascension"       then val = d.ascensions or 0
                elseif t.type=="total_playtime"  then val = d.totalPlaytime or 0
                end
                match = val >= t.amount
            end
        end
        if match then
            d.achievements[a.id] = true
            if a.reward.type == "rizz" then
                d.rizzTokens += a.reward.amount
            elseif a.reward.type == "sigma" then
                d.sigma += a.reward.amount ; d.allTimeSigma += a.reward.amount
            end
            AchieveUnlockEvent:FireClient(player, {
                id=a.id, name=a.name, emoji=a.emoji, desc=a.desc, reward=a.reward,
            })
        end
    end
end

-- ── Rank label / prestige badge / speed ───────────────────────────────────
local function applyRankLabel(player, rank)
    local char = player.Character ; if not char then return end
    local head = char:FindFirstChild("Head") ; if not head then return end
    local old  = head:FindFirstChild("RankBillboard") ; if old then old:Destroy() end
    local bb = Instance.new("BillboardGui")
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
local function applyPrestigeBadge(player)
    local d=pData[player.UserId] ; if not d or d.prestige<=0 then return end
    local char=player.Character ; if not char then return end
    local head=char:FindFirstChild("Head") ; if not head then return end
    local old=head:FindFirstChild("PrestigeBadge") ; if old then old:Destroy() end
    local bb=Instance.new("BillboardGui")
    bb.Name="PrestigeBadge" ; bb.Size=UDim2.new(0,160,0,32)
    bb.StudsOffset=Vector3.new(0,3,0) ; bb.AlwaysOnTop=true ; bb.Parent=head
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,0,1,0) ; lbl.BackgroundTransparency=1
    local pStr = d.ascensions and d.ascensions>0
        and ("✨P"..d.prestige.." A"..d.ascensions)
        or  ("⭐ PRESTIGE "..d.prestige)
    lbl.Text=pStr
    lbl.TextColor3=Color3.fromRGB(255,215,0) ; lbl.TextScaled=true
    lbl.Font=Enum.Font.GothamBold ; lbl.Parent=bb
end
local function applySpeed(player)
    local d=pData[player.UserId] ; if not d then return end
    local char=player.Character ; if not char then return end
    local hum=char:FindFirstChild("Humanoid")
    if hum then hum.WalkSpeed=BASE_SPEED+d.prestige*SPEED_PER_PREST end
end

-- ── Sync to client ─────────────────────────────────────────────────────────
local function sync(player, gain, label)
    local d = pData[player.UserId] ; if not d then return end
    local rank = rankFor(d.sigma)
    local nxt  = nextRankFor(d.sigma)
    local old  = lastRanks[player.UserId]
    if old and old ~= rank.name then
        d.rizzTokens += 10
        ServerAnnounceEvent:FireAllClients({
            text  = player.Name.." ranked up to "..rank.emoji.." "..rank.name.."! +10💎",
            color = "gold",
        })
        applyRankLabel(player, rank)
    end
    lastRanks[player.UserId] = rank.name
    player.leaderstats.Sigma.Value    = d.sigma
    player.leaderstats.Rank.Value     = rank.emoji.." "..rank.name
    player.leaderstats.Prestige.Value = d.prestige

    local spinSecsLeft = 0
    if spinBoost[player.UserId] then
        spinSecsLeft = math.max(0, math.floor(spinBoost[player.UserId] - os.clock()))
    end

    UpdateUIEvent:FireClient(player, {
        sigma          = d.sigma,
        allTimeSigma   = d.allTimeSigma,
        multiplier     = effectiveMulti(d),
        petIncome      = petIncome(d),
        prestige       = d.prestige,
        ascensions     = d.ascensions or 0,
        ascendMulti    = ascendMulti(d),
        prestThresh    = PRESTIGE_THRESH,
        ascendUnlocked = (d.prestige or 0) >= ASCEND_PRESTIGE,
        rank           = rank,
        nextRank       = nxt,
        lastGain       = gain  or 0,
        critLabel      = label or "",
        rizzTokens     = d.rizzTokens,
        ownedPets      = d.ownedPets,
        equippedPets   = d.pets,
        evolvedPets    = d.evolvedPets,
        coopBoost      = coopActive,
        questProgress  = d.questProgress,
        questDone      = d.questDone,
        achievements   = d.achievements,
        dailyStreak    = d.dailyStreak    or 0,
        lastDailyClaim = d.lastDailyClaim or 0,
        lastSpin       = d.lastSpin       or 0,
        freeSlotClaimed= d.freeSlotClaimed or {},
        spinBoostLeft  = spinSecsLeft,
    })
    print("[DEBUG] SERVER_UI_UPDATE_SENT to", player.Name, "sigma="..tostring(d.sigma))
end

-- ── Player lifecycle ──────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
    local ls=Instance.new("Folder") ; ls.Name="leaderstats" ; ls.Parent=player
    local function val(cls,name,def)
        local v=Instance.new(cls); v.Name=name; v.Value=def; v.Parent=ls
    end
    val("IntValue","Sigma",0) ; val("StringValue","Rank","🤡 NPC") ; val("IntValue","Prestige",0)

    local d = loadData(player.UserId)

    -- Offline earnings
    local now     = os.time()
    local elapsed = math.min(now - (d.lastSeen or now), OFFLINE_CAP_SECS)
    if elapsed > 60 then
        local offline_income = petIncome(d) * elapsed
        if offline_income > 0 then
            d.sigma        += math.floor(offline_income)
            d.allTimeSigma += math.floor(offline_income)
            task.delay(3, function()
                local p2 = getPlayerById(player.UserId)
                if p2 then
                    ServerAnnounceEvent:FireClient(p2, {
                        text  = "💤 Offline earnings: +"..math.floor(offline_income)
                               .."σ  ("..math.floor(elapsed/60).." min)",
                        color = "gold",
                    })
                end
            end)
        end
    end
    d.lastSeen    = now
    d.sessionStart= now
    d.lastAfkRizz = now
    d._uid        = player.UserId

    -- Rebuild baseMulti from owned upgrades
    d.baseMulti = 1
    for key, owned in pairs(d.owned or {}) do
        if owned then
            local id = tonumber(key)
            for _, u in ipairs(Upgrades) do
                if u.id == id and u.effect == "click_multiplier" then
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

    task.wait(1.2)
    sync(player, 0, "")
    QuestUpdateEvent:FireClient(player, {
        questProgress=d.questProgress, questDone=d.questDone,
    })
end)

Players.PlayerRemoving:Connect(function(player)
    local dState = duels[player.UserId]
    if dState then
        local opp = getPlayerById(dState.opponentId)
        if opp then DuelCancelEvent:FireClient(opp, {reason="opponent_left"}) end
        duels[dState.opponentId] = nil ; duels[player.UserId] = nil
    end
    for uid, pend in pairs(duelPend) do
        if uid==player.UserId or pend.challengerUid==player.UserId then
            duelPend[uid]=nil
        end
    end
    local d = pData[player.UserId]
    if d then d.lastSeen=os.time() ; saveData(player.UserId, d) end
    pData[player.UserId]=nil ; combos[player.UserId]=nil
    lastRanks[player.UserId]=nil ; godClickTimes[player.UserId]=nil
    godModeActive[player.UserId]=nil ; spinBoost[player.UserId]=nil
end)

game:BindToClose(function()
    for _, p in ipairs(Players:GetPlayers()) do
        local d = pData[p.UserId]
        if d then d.lastSeen=os.time() ; saveData(p.UserId, d) end
    end
    task.wait(2)
end)

-- Auto-save every 60s
task.spawn(function()
    while true do
        task.wait(60)
        for _, p in ipairs(Players:GetPlayers()) do
            local d = pData[p.UserId]
            if d then d.lastSeen=os.time() ; saveData(p.UserId, d) end
        end
    end
end)

-- Pet income tick (1s)
task.spawn(function()
    while true do
        task.wait(1)
        for _, p in ipairs(Players:GetPlayers()) do
            local d = pData[p.UserId]
            if d then
                local inc = petIncome(d)
                if inc > 0 then
                    d.sigma += inc ; d.allTimeSigma += inc
                    sync(p, 0, "")
                end
            end
        end
    end
end)

-- AFK Rizz reward (every 30s, accumulates toward 5-min threshold)
task.spawn(function()
    while true do
        task.wait(30)
        local now = os.time()
        for _, p in ipairs(Players:GetPlayers()) do
            local d = pData[p.UserId]
            if d then
                d.totalPlaytime = (d.totalPlaytime or 0) + 30
                if now - (d.lastAfkRizz or now) >= AFK_RIZZ_INTERVAL then
                    d.lastAfkRizz = now
                    d.rizzTokens += AFK_RIZZ_AMOUNT
                    ServerAnnounceEvent:FireClient(p, {
                        text  = "⏳ AFK Reward! +"..AFK_RIZZ_AMOUNT.."💎 for staying in-game!",
                        color = "gold",
                    })
                    sync(p, 0, "")
                    updateQuest(p, "playtime", 30)
                    checkAchieve(p, "total_playtime", 0)
                end
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
    local d = pData[player.UserId] ; if not d then return end
    print("[DEBUG] SERVER_CLICK_RECEIVED from", player.Name)
    local uid = player.UserId

    godClickTimes[uid] = godClickTimes[uid] or {}
    local t = os.clock()
    table.insert(godClickTimes[uid], t)
    local cut = t - GOD_WINDOW
    while godClickTimes[uid][1] and godClickTimes[uid][1] < cut do
        table.remove(godClickTimes[uid], 1)
    end
    if #godClickTimes[uid] >= GOD_CLICKS and not godModeActive[uid] then
        godModeActive[uid] = true
        GodModeActiveEvent:FireClient(player)
        ServerAnnounceEvent:FireAllClients({
            text="⚡ "..player.Name.." entered SIGMA GOD MODE!", color="gold",
        })
        task.delay(GOD_DURATION, function()
            godModeActive[uid]=false ; godClickTimes[uid]={}
            GodModeEndedEvent:FireClient(player)
        end)
    end

    local cr   = rollCrit()
    local godB = godModeActive[uid] and GOD_MULT or 1
    local gain = math.max(1, math.floor(
        effectiveMulti(d) * cr.mult * evMult.Value
        * (combos[uid] and 1.5 or 1) * godB
    ))
    d.sigma += gain ; d.allTimeSigma += gain
    print("[DEBUG] SERVER_REWARD_GRANTED +"..tostring(gain).." -> sigma now "..tostring(d.sigma))
    d.totalClicks = (d.totalClicks or 0) + 1
    sync(player, gain, cr.label)

    updateQuest(player, "clicks", 1)
    checkAchieve(player, "clicks", d.totalClicks)
    checkAchieve(player, "total_sigma", 0)
end)

ComboActiveEvent.OnServerEvent:Connect(function(p) combos[p.UserId]=true  end)
ComboEndedEvent.OnServerEvent:Connect(function(p)  combos[p.UserId]=false end)

-- ── Upgrade purchase ──────────────────────────────────────────────────────
BuyUpgradeEvent.OnServerEvent:Connect(function(player, upgradeId)
    local d = pData[player.UserId] ; if not d then return end
    local u = nil
    for _, up in ipairs(Upgrades) do if up.id==upgradeId then u=up ; break end end
    if not u then return end
    if d.owned[tostring(u.id)] then return end
    if d.sigma < u.cost then return end
    d.sigma -= u.cost
    d.owned[tostring(u.id)] = true
    if u.effect=="click_multiplier" then d.baseMulti *= u.value end
    sync(player, 0, "")
end)

-- ── Prestige ──────────────────────────────────────────────────────────────
PrestigeEvent.OnServerEvent:Connect(function(player)
    local d = pData[player.UserId]
    if not d or d.sigma < PRESTIGE_THRESH then return end
    d.prestige   += 1 ; d.sigma=0 ; d.baseMulti=1 ; d.owned={}
    d.rizzTokens += 25
    saveData(player.UserId, d)
    ServerAnnounceEvent:FireAllClients({
        text  = "⭐ "..player.Name.." PRESTIGED! Prestige "..d.prestige
               .."  ("..prestigeBonus(d.prestige).."x permanent bonus)",
        color = "purple",
    })
    applyPrestigeBadge(player) ; applySpeed(player) ; sync(player, 0, "")
    checkAchieve(player, "prestige", d.prestige)
    updateQuest(player, "prestige", 1)
    if d.prestige == 1 then
        ServerAnnounceEvent:FireClient(player, {
            text="🎉 Auto-reroll on duplicates is now active!", color="gold",
        })
    end
    if d.prestige == ASCEND_PRESTIGE then
        ServerAnnounceEvent:FireClient(player, {
            text="✨ Prestige 5 reached! TRUE RESET (Ascension) is now unlocked!", color="purple",
        })
    end
end)

-- ── Ascension ─────────────────────────────────────────────────────────────
AscendEvent.OnServerEvent:Connect(function(player)
    local d = pData[player.UserId]
    if not d or (d.prestige or 0) < ASCEND_PRESTIGE then return end
    d.ascensions    = (d.ascensions or 0) + 1
    d.sigma         = 0 ; d.baseMulti=1 ; d.owned={}
    d.prestige      = 0
    d.pets          = {1} ; d.ownedPets={["1"]=1} ; d.evolvedPets={}
    d.rizzTokens    = (d.rizzTokens or 0) + 50
    saveData(player.UserId, d)
    local newMult = ascendMulti(d)
    ServerAnnounceEvent:FireAllClients({
        text  = "✨ "..player.Name.." ASCENDED! ("..newMult.."x permanent multiplier)",
        color = "purple",
    })
    applyPrestigeBadge(player) ; applySpeed(player) ; sync(player, 0, "")
    checkAchieve(player, "ascension", d.ascensions)
end)

-- ── Egg hatching ──────────────────────────────────────────────────────────
local function rollEgg(eggDef)
    local r = math.random(1, 100)
    local rarity
    if     r <= eggDef.weights.Legendary then
        rarity = "Legendary"
    elseif r <= eggDef.weights.Legendary + eggDef.weights.Rare then
        rarity = "Rare"
    else
        rarity = "Common"
    end
    local pool = PET_BY_RARITY[rarity] or PET_BY_RARITY["Common"]
    return pool[math.random(1, #pool)]
end

local function doHatch(player, d, eggDef)
    if d.rizzTokens < eggDef.cost then return nil end
    d.rizzTokens -= eggDef.cost
    local petDef = rollEgg(eggDef)
    local key    = tostring(petDef.id)
    d.ownedPets  = d.ownedPets or {}
    local isDuplicate = (d.ownedPets[key] or 0) > 0
    -- Auto-reroll at prestige 1+
    if isDuplicate and (d.prestige or 0) >= 1 then
        local rp   = rollEgg(eggDef)
        local rKey = tostring(rp.id)
        if not ((d.ownedPets[rKey] or 0) > 0) then
            petDef = rp ; key = rKey ; isDuplicate = false
        end
    end
    d.ownedPets[key] = (d.ownedPets[key] or 0) + 1
    local rizzBonus = 0
    if isDuplicate then
        rizzBonus = DUP_RIZZ[petDef.rarity] or 3
        d.rizzTokens += rizzBonus
    end
    d.totalHatches = (d.totalHatches or 0) + 1
    updateQuest(player, "hatches", 1)
    checkAchieve(player, "hatches", d.totalHatches)
    checkAchieve(player, "rarity", 1, petDef.rarity)
    checkAchieve(player, "all_pets", 0)
    return { petId=petDef.id, eggId=eggDef.id, rarity=petDef.rarity, isDuplicate=isDuplicate, rizzBonus=rizzBonus }
end

HatchEggEvent.OnServerEvent:Connect(function(player, eggId)
    local d      = pData[player.UserId] ; if not d then return end
    local eggDef = eggDefById[eggId]    ; if not eggDef then return end
    local result = doHatch(player, d, eggDef) ; if not result then return end
    HatchResultEvent:FireClient(player, result)
    sync(player, 0, "")
end)

RerollEggEvent.OnServerEvent:Connect(function(player, eggId)
    local d      = pData[player.UserId] ; if not d then return end
    local eggDef = eggDefById[eggId]    ; if not eggDef then return end
    local cost   = math.max(1, math.ceil(eggDef.cost / 2))
    if d.rizzTokens < cost then return end
    d.rizzTokens -= cost
    local petDef = rollEgg(eggDef)
    local key    = tostring(petDef.id)
    d.ownedPets  = d.ownedPets or {}
    local isDuplicate = (d.ownedPets[key] or 0) > 0
    d.ownedPets[key] = (d.ownedPets[key] or 0) + 1
    local rizzBonus = 0
    if isDuplicate then rizzBonus=DUP_RIZZ[petDef.rarity] or 3 ; d.rizzTokens+=rizzBonus end
    d.totalHatches = (d.totalHatches or 0) + 1
    updateQuest(player, "hatches", 1)
    HatchResultEvent:FireClient(player, {
        petId=petDef.id, eggId=eggId, rarity=petDef.rarity,
        isDuplicate=isDuplicate, rizzBonus=rizzBonus, isReroll=true,
    })
    sync(player, 0, "")
end)

AutoRollToggleEvent.OnServerEvent:Connect(function(player, eggId)
    local uid = player.UserId
    if autoRollState[uid] == eggId then
        autoRollState[uid] = nil
        AutoRollStatusEvent:FireClient(player, {active=false})
        return
    end
    autoRollState[uid] = eggId
    AutoRollStatusEvent:FireClient(player, {active=true, eggId=eggId})
    task.spawn(function()
        while autoRollState[uid] == eggId do
            task.wait(1.8)
            if autoRollState[uid] ~= eggId then break end
            local d = pData[uid] ; if not d then break end
            local eggDef = eggDefById[eggId] ; if not eggDef then break end
            if d.rizzTokens < eggDef.cost then
                autoRollState[uid] = nil
                AutoRollStatusEvent:FireClient(player, {active=false, reason="broke"})
                break
            end
            local result = doHatch(player, d, eggDef)
            if result then
                result.isAutoRoll    = true
                result.skipCinematic = (petDefById[result.petId].rarity ~= "Legendary")
                HatchResultEvent:FireClient(player, result)
                sync(player, 0, "")
            end
        end
    end)
end)

-- ── Pet Evolution ─────────────────────────────────────────────────────────
EvolvePetEvent.OnServerEvent:Connect(function(player, petId)
    local d   = pData[player.UserId] ; if not d then return end
    local key = tostring(petId)
    if not d.ownedPets[key] or d.ownedPets[key] < 3 then return end
    d.ownedPets[key]   = d.ownedPets[key] - 2
    d.evolvedPets      = d.evolvedPets or {}
    d.evolvedPets[key] = true
    d.totalEvolutions  = (d.totalEvolutions or 0) + 1
    local petDef = petDefById[petId]
    EvolvePetResultEvent:FireClient(player, {
        petId=petId,
        evolvedName  = petDef and petDef.evolvedName  or "Evolved Pet",
        evolvedEmoji = petDef and petDef.evolvedEmoji or "🌟",
    })
    ServerAnnounceEvent:FireAllClients({
        text  = "🌟 "..player.Name.." evolved "
               ..(petDef and petDef.name or "a pet").." → "
               ..(petDef and petDef.evolvedName or "Evolved!"),
        color = "gold",
    })
    sync(player, 0, "")
    updateQuest(player, "evolutions", 1)
    checkAchieve(player, "evolution", d.totalEvolutions)
end)

-- ── Exchange / Equip ──────────────────────────────────────────────────────
ExchangePetEvent.OnServerEvent:Connect(function(player, petId)
    local d   = pData[player.UserId] ; if not d then return end
    local key = tostring(petId)
    if not d.ownedPets[key] or d.ownedPets[key] < 2 then return end
    d.ownedPets[key] -= 1
    local petDef = petDefById[petId]
    d.rizzTokens += petDef and (DUP_RIZZ[petDef.rarity] or 3) or 3
    sync(player, 0, "")
end)

EquipPetEvent.OnServerEvent:Connect(function(player, petId)
    local d   = pData[player.UserId] ; if not d then return end
    local key = tostring(petId)
    if not d.ownedPets[key] or d.ownedPets[key] < 1 then return end
    for i, id in ipairs(d.pets) do
        if id == petId then table.remove(d.pets, i) ; sync(player, 0, "") ; return end
    end
    if #d.pets >= 3 then table.remove(d.pets, 1) end
    table.insert(d.pets, petId) ; sync(player, 0, "")
end)

-- ── Rizz Spin Wheel ───────────────────────────────────────────────────────
SpinWheelEvent.OnServerEvent:Connect(function(player, isPaid)
    local d   = pData[player.UserId] ; if not d then return end
    local now = os.time()
    if isPaid then
        if d.rizzTokens < SPIN_PAID_COST then return end
        d.rizzTokens -= SPIN_PAID_COST
    else
        if now - (d.lastSpin or 0) < SPIN_FREE_COOLDOWN then return end
    end
    d.lastSpin   = now
    d.totalSpins = (d.totalSpins or 0) + 1

    local totalW = 0
    for _, p in ipairs(SpinPrizesDef) do totalW += p.weight end
    local r    = math.random(1, totalW)
    local cumW = 0
    local prize = SpinPrizesDef[#SpinPrizesDef]
    for idx, p in ipairs(SpinPrizesDef) do
        cumW += p.weight
        if r <= cumW then prize = p ; break end
    end

    if prize.type == "rizz" then
        d.rizzTokens += prize.amount
    elseif prize.type == "sigma" then
        d.sigma += prize.amount ; d.allTimeSigma += prize.amount
    elseif prize.type == "boost" then
        spinBoost[player.UserId] = os.clock() + prize.amount
    end

    SpinResultEvent:FireClient(player, { prize=prize })
    sync(player, 0, "")
    updateQuest(player, "spins", 1)
end)

-- ── Daily Rewards ─────────────────────────────────────────────────────────
ClaimDailyEvent.OnServerEvent:Connect(function(player)
    local d   = pData[player.UserId] ; if not d then return end
    local now = os.time()
    if now - (d.lastDailyClaim or 0) < DAILY_COOLDOWN then return end
    if now - (d.lastDailyClaim or 0) > 48*3600 and (d.lastDailyClaim or 0) > 0 then
        d.dailyStreak = 0
    end
    d.dailyStreak    = (d.dailyStreak or 0) + 1
    d.lastDailyClaim = now
    local dayIdx  = ((d.dailyStreak - 1) % #DailyRewardsDef) + 1
    local reward  = DailyRewardsDef[dayIdx]
    if reward.reward.type == "rizz" then
        d.rizzTokens += reward.reward.amount
    elseif reward.reward.type == "sigma" then
        d.sigma += reward.reward.amount ; d.allTimeSigma += reward.reward.amount
    end
    sync(player, 0, "")
    ServerAnnounceEvent:FireClient(player, {
        text  = "📅 Day "..d.dailyStreak.." Daily Reward! "..reward.label,
        color = "gold",
    })
end)

-- ── Free Rewards ──────────────────────────────────────────────────────────
FreeRewardEvent.OnServerEvent:Connect(function(player, slotId)
    local d    = pData[player.UserId] ; if not d then return end
    local slot = nil
    for _, s in ipairs(FREE_SLOTS) do if s.id == slotId then slot=s ; break end end
    if not slot then return end
    local now = os.time()
    d.freeSlotClaimed = d.freeSlotClaimed or {}
    if now - (d.freeSlotClaimed[slotId] or 0) < slot.cooldown then return end
    d.freeSlotClaimed[slotId] = now
    if slot.reward.type == "rizz" then
        d.rizzTokens += slot.reward.amount
    elseif slot.reward.type == "sigma" then
        d.sigma += slot.reward.amount ; d.allTimeSigma += slot.reward.amount
    end
    sync(player, 0, "")
    ServerAnnounceEvent:FireClient(player, {
        text  = "🎁 Free Reward! +"..slot.reward.amount
               ..(slot.reward.type=="rizz" and "💎" or "σ"),
        color = "gold",
    })
end)

-- ── Co-op boost monitor ───────────────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(5)
        local active = #Players:GetPlayers() >= 2
        if active ~= coopActive then
            coopActive = active
            for _, p in ipairs(Players:GetPlayers()) do
                CoopBoostEvent:FireClient(p, active)
            end
        end
    end
end)

-- ── Leaderboard broadcaster ───────────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(10)
        local entries = {}
        for _, p in ipairs(Players:GetPlayers()) do
            local d = pData[p.UserId]
            if d then table.insert(entries, {name=p.Name, sigma=d.sigma, prestige=d.prestige}) end
        end
        table.sort(entries, function(a, b) return a.sigma > b.sigma end)
        local top5 = {}
        for i = 1, math.min(5, #entries) do top5[i] = entries[i] end
        for _, p in ipairs(Players:GetPlayers()) do
            LeaderboardUpdateEvent:FireClient(p, top5)
        end
    end
end)

-- ── Online players list ───────────────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(5)
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do table.insert(names, p.Name) end
        for _, p in ipairs(Players:GetPlayers()) do
            OnlinePlayersEvent:FireClient(p, names)
        end
    end
end)

-- ── Wandering NPC spawns ──────────────────────────────────────────────────
local MAX_NPCS = 5 ; local npcCount = 0
local function spawnWanderingNpc()
    if npcCount >= MAX_NPCS then return end ; npcCount += 1
    local part = Instance.new("Part")
    part.Size=Vector3.new(2,3,2) ; part.BrickColor=BrickColor.new("Bright red")
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
    local cd=Instance.new("ClickDetector") ; cd.MaxActivationDistance=25 ; cd.Parent=part
    cd.MouseClick:Connect(function(player)
        local d=pData[player.UserId] ; if not d then return end
        d.sigma+=30 ; d.allTimeSigma+=30 ; sync(player,30,"NICE")
        npcCount-=1 ; part:Destroy()
    end)
    task.spawn(function()
        local lifetime=math.random(12,25) ; local elapsed=0
        while elapsed<lifetime and part.Parent do
            local tx=math.random(-44,44) ; local tz=math.random(-44,44)
            local dist=math.sqrt((tx-part.Position.X)^2+(tz-part.Position.Z)^2)
            local dur=math.max(dist/7,0.5)
            local sx,sz=part.Position.X,part.Position.Z ; local t2=0
            while t2<dur and part.Parent do
                task.wait(0.15) ; t2+=0.15
                local f=math.min(t2/dur,1)
                part.CFrame=CFrame.new(sx+(tx-sx)*f,1.5,sz+(tz-sz)*f)
            end
            elapsed+=dur ; task.wait(0.5) ; elapsed+=0.5
        end
        if part and part.Parent then npcCount-=1 ; part:Destroy() end
    end)
end
task.spawn(function() while true do task.wait(12) ; spawnWanderingNpc() end end)

-- ── Event system ──────────────────────────────────────────────────────────
local function makePart(cf, size, colorName, label)
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
    return part, cd
end
local function rndCF()
    return CFrame.new(math.random(-50,50),3,math.random(-50,50))
end
local function runEvent(event)
    for _, p in ipairs(Players:GetPlayers()) do EventNotifyEvent:FireClient(p, event) end
    local cleanup = {}
    if event.effect=="sigma_multiplier" then
        evMult.Value=event.value
        table.insert(cleanup, function() evMult.Value=1 end)
    elseif event.effect=="rizz_tokens" then
        local coins={}
        for _=1,8 do
            local coin=Instance.new("Part")
            coin.Size=Vector3.new(2.5,2.5,2.5) ; coin.Shape=Enum.PartType.Ball
            coin.BrickColor=BrickColor.new("Bright yellow") ; coin.Material=Enum.Material.Neon
            coin.CFrame=CFrame.new(math.random(-50,50),math.random(25,50),math.random(-50,50))
            coin.Anchored=false ; coin.Parent=Workspace
            local bb=Instance.new("BillboardGui")
            bb.Size=UDim2.new(0,120,0,32) ; bb.StudsOffset=Vector3.new(0,2.5,0)
            bb.AlwaysOnTop=true ; bb.Parent=coin
            local lbl=Instance.new("TextLabel")
            lbl.Size=UDim2.new(1,0,1,0) ; lbl.BackgroundTransparency=1
            lbl.Text="💎 +"..event.value.." Rizz!"
            lbl.TextColor3=Color3.fromRGB(255,215,0) ; lbl.TextScaled=true
            lbl.Font=Enum.Font.GothamBold ; lbl.Parent=bb
            table.insert(coins, coin)
            local collected=false
            coin.Touched:Connect(function(hit)
                if collected then return end
                local hitPlayer=Players:GetPlayerFromCharacter(hit.Parent)
                if not hitPlayer then return end
                local d=pData[hitPlayer.UserId] ; if not d then return end
                collected=true ; d.rizzTokens+=event.value ; sync(hitPlayer,0,"") ; coin:Destroy()
            end)
        end
        table.insert(cleanup, function()
            for _, c in ipairs(coins) do if c and c.Parent then c:Destroy() end end
        end)
    elseif event.effect=="bonus_clicks" then
        local part,cd=makePart(CFrame.new(0,6,0),Vector3.new(6,10,6),"Bright orange","👑 GIGACHAD! +500σ")
        local claimed={}
        table.insert(cleanup, function() if part and part.Parent then part:Destroy() end end)
        cd.MouseClick:Connect(function(player)
            if claimed[player.UserId] then return end ; claimed[player.UserId]=true
            local d=pData[player.UserId] ; if not d then return end
            d.sigma+=event.value ; d.allTimeSigma+=event.value
            sync(player, event.value, "GIGACHAD!!")
        end)
    elseif event.effect=="npc_targets" then
        local npcs={}
        for _=1,10 do
            local part,cd=makePart(rndCF(),Vector3.new(3,4,3),"Bright red","☠️ NPC! +100σ")
            table.insert(npcs, part)
            cd.MouseClick:Connect(function(player)
                local d=pData[player.UserId] ; if not d then return end
                d.sigma+=100 ; d.allTimeSigma+=100 ; sync(player,100,"SIGMA!") ; part:Destroy()
            end)
        end
        table.insert(cleanup, function()
            for _, n in ipairs(npcs) do if n and n.Parent then n:Destroy() end end
        end)
    elseif event.effect=="lottery_jackpot" then
        local orb,cd=makePart(CFrame.new(0,7,0),Vector3.new(5,5,5),"Cyan",
            "🎰 JACKPOT! +"..event.value.."σ — First click wins!")
        orb.Shape=Enum.PartType.Ball ; orb.Material=Enum.Material.Neon
        local won=false
        table.insert(cleanup, function() if orb and orb.Parent then orb:Destroy() end end)
        cd.MouseClick:Connect(function(player)
            if won then return end ; won=true
            local d=pData[player.UserId] ; if not d then return end
            d.sigma+=event.value ; d.allTimeSigma+=event.value
            sync(player, event.value, "GIGACHAD!!")
            ServerAnnounceEvent:FireAllClients({
                text="🎰 "..player.Name.." won the Sigma Lottery! +"..event.value.."σ!",
                color="gold",
            })
            orb:Destroy()
        end)
    end
    task.wait(event.duration)
    for _, fn in ipairs(cleanup) do fn() end
    for _, p in ipairs(Players:GetPlayers()) do EventNotifyEvent:FireClient(p, nil) end
end

task.spawn(function()
    task.wait(15)
    while true do
        local event=Events[math.random(1,#Events)]
        runEvent(event) ; task.wait(math.random(30,60))
    end
end)

-- ── Duel system ───────────────────────────────────────────────────────────
DuelChallengeEvent.OnServerEvent:Connect(function(challenger, targetName)
    local target=nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name==targetName then target=p ; break end
    end
    if not target or target==challenger then return end
    if duels[challenger.UserId] or duels[target.UserId] then return end
    if duelPend[target.UserId] then return end
    duelPend[target.UserId]={challengerUid=challenger.UserId, expireAt=os.clock()+15}
    DuelInviteEvent:FireClient(target, {challengerName=challenger.Name})
    task.delay(15, function()
        local pend=duelPend[target.UserId]
        if pend and pend.challengerUid==challenger.UserId then duelPend[target.UserId]=nil end
    end)
end)

DuelAcceptEvent.OnServerEvent:Connect(function(target)
    local pend=duelPend[target.UserId]
    if not pend or os.clock()>pend.expireAt then return end
    local challenger=getPlayerById(pend.challengerUid)
    if not challenger then duelPend[target.UserId]=nil ; return end
    duelPend[target.UserId]=nil
    duels[challenger.UserId]={opponentId=target.UserId,   clicks=0, active=true}
    duels[target.UserId]    ={opponentId=challenger.UserId,clicks=0, active=true}
    DuelStartEvent:FireClient(challenger, {opponentName=target.Name})
    DuelStartEvent:FireClient(target,     {opponentName=challenger.Name})
    task.spawn(function()
        for remaining=30,1,-1 do
            task.wait(1)
            local cS=duels[challenger.UserId] ; local tS=duels[target.UserId]
            if not cS or not tS then return end
            DuelUpdateEvent:FireClient(challenger,{myClicks=cS.clicks,theirClicks=tS.clicks,timeLeft=remaining-1})
            DuelUpdateEvent:FireClient(target,    {myClicks=tS.clicks,theirClicks=cS.clicks,timeLeft=remaining-1})
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
            wd.sigma+=actual ; wd.allTimeSigma+=actual
            sync(winner,actual,"SIGMA!") ; sync(loser,0,"")
        end
        DuelResultEvent:FireClient(challenger,{winnerName=winner.Name,sigmaStake=STAKE})
        DuelResultEvent:FireClient(target,    {winnerName=winner.Name,sigmaStake=STAKE})
        ServerAnnounceEvent:FireAllClients({
            text="⚔️ "..winner.Name.." defeated "..loser.Name.." in a Sigma Duel!",color="gold",
        })
        duels[challenger.UserId]=nil ; duels[target.UserId]=nil
    end)
end)

DuelDeclineEvent.OnServerEvent:Connect(function(target)
    local pend=duelPend[target.UserId] ; if not pend then return end
    local challenger=getPlayerById(pend.challengerUid)
    duelPend[target.UserId]=nil
    if challenger then DuelCancelEvent:FireClient(challenger,{reason="declined"}) end
end)

DuelClickEvent.OnServerEvent:Connect(function(player)
    local s=duels[player.UserId]
    if s and s.active then s.clicks+=1 end
end)
