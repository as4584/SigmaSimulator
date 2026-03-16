-- SoundManager.client.lua
-- Handles all game sound effects.
-- Sound IDs reference the Roblox free audio library — swap from Creator Store if desired.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService      = game:GetService("SoundService")
local Debris            = game:GetService("Debris")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ── Sound ID table (rbxassetid://ID) ──────────────────────────────────────
-- Replace any ID with one from the Roblox Creator Store audio library
local SFX = {
    click         = 418252437,   -- light UI click
    crit_nice     = 418252437,
    crit_sigma    = 4612332441,  -- positive fanfare
    crit_gigachad = 3338724701,  -- heavy hit
    rankup        = 4612332441,
    prestige      = 3338724701,
    event_start   = 4612332441,
    god_mode      = 3338724701,
    hatch         = 4612332441,
    duel_win      = 4612332441,
    duel_lose     = 3338724701,
}

local function play(id, volume)
    local s = Instance.new("Sound")
    s.SoundId  = "rbxassetid://" .. id
    s.Volume   = volume or 0.5
    s.RollOffMaxDistance = 0
    s.Parent   = SoundService
    s:Play()
    Debris:AddItem(s, 6)
end

-- ── Click / crit sounds ───────────────────────────────────────────────────
local lastGainTracked = 0
Remotes:WaitForChild("UpdateUI").OnClientEvent:Connect(function(data)
    if not data.lastGain or data.lastGain <= 0 then return end
    if data.lastGain == lastGainTracked then return end
    lastGainTracked = data.lastGain
    local lbl = data.critLabel or ""
    if     lbl == "GIGACHAD!!" then play(SFX.crit_gigachad)
    elseif lbl == "SIGMA!"     then play(SFX.crit_sigma)
    elseif lbl == "NICE"       then play(SFX.crit_nice)
    else                            play(SFX.click, 0.3)
    end
end)

-- ── Rank-up ───────────────────────────────────────────────────────────────
local prevRankName = ""
Remotes:WaitForChild("UpdateUI").OnClientEvent:Connect(function(data)
    local rName = data.rank and data.rank.name or ""
    if rName ~= prevRankName and prevRankName ~= "" then
        play(SFX.rankup)
    end
    prevRankName = rName
end)

-- ── Prestige (purple ServerAnnounce) ─────────────────────────────────────
Remotes:WaitForChild("ServerAnnounce").OnClientEvent:Connect(function(data)
    if data.color == "purple" then play(SFX.prestige) end
end)

-- ── God Mode ─────────────────────────────────────────────────────────────
Remotes:WaitForChild("GodModeActive").OnClientEvent:Connect(function()
    play(SFX.god_mode, 0.8)
end)

-- ── Event start ──────────────────────────────────────────────────────────
Remotes:WaitForChild("EventNotify").OnClientEvent:Connect(function(event)
    if event then play(SFX.event_start) end
end)

-- ── Egg hatch ─────────────────────────────────────────────────────────────
Remotes:WaitForChild("HatchResult").OnClientEvent:Connect(function()
    play(SFX.hatch)
end)

-- ── Duel result ───────────────────────────────────────────────────────────
local me = game:GetService("Players").LocalPlayer
Remotes:WaitForChild("DuelResult").OnClientEvent:Connect(function(data)
    if data.winnerName == me.Name then
        play(SFX.duel_win)
    else
        play(SFX.duel_lose)
    end
end)
