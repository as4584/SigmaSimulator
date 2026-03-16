-- CharacterManager.client.lua
-- Transforms the local player's character appearance as they level up.
-- Body proportions, skin tone, face, and accessories all evolve with rank.
--
-- LOOK TIERS (driven by rank index 1-11 + prestige):
--   Tier 0  rank 1  NPC        – big dumb head, stumpy body, grey skin, derp face
--   Tier 1  rank 2  Normie     – slightly less bad. pale-ish skin
--   Tier 2  rank 3  Gym Bro    – normal proportions, healthy skin, buff
--   Tier 3  rank 4-5 Lone Wolf/Sigma – tall & defined, tan, basic shades accessory
--   Tier 4  rank 6-7 Ohio/Rizzler  – imposing, bronze skin, cool shades
--   Tier 5  rank 8+ Gigachad+  – maximum chad, golden skin, crown + chain
--   Prestige overlay – each prestige level adds a face sparkle particle

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- ── Body scale targets per tier ───────────────────────────────────────────
-- { HeadScale, BodyHeight, BodyWidth, BodyDepth, BodyProportions }
-- All R15 NumberValues; stock defaults are all 1.0
local BODY_TIERS = {
    [0] = { head=1.85, height=0.72, width=0.70, depth=0.80, prop=0.0 },  -- NPC:   comically big head, stumpy
    [1] = { head=1.45, height=0.85, width=0.80, depth=0.88, prop=0.1 },  -- Normie: still bad
    [2] = { head=1.15, height=1.00, width=1.06, depth=0.98, prop=0.4 },  -- Gym Bro: normal+
    [3] = { head=1.00, height=1.10, width=1.12, depth=1.02, prop=0.6 },  -- Lone Wolf / Sigma
    [4] = { head=0.97, height=1.16, width=1.18, depth=1.04, prop=0.8 },  -- Ohio / Rizzler
    [5] = { head=0.93, height=1.25, width=1.25, depth=1.08, prop=1.0 },  -- Gigachad+: tall, wide, tiny head
}

-- ── Skin color targets per tier ───────────────────────────────────────────
local SKIN_TIERS = {
    [0] = BrickColor.new("Medium stone grey"),
    [1] = BrickColor.new("Pastel brown"),
    [2] = BrickColor.new("Nougat"),
    [3] = BrickColor.new("Light orange"),
    [4] = BrickColor.new("Bright orange"),
    [5] = BrickColor.new("Warm yellowish orange"),
}

-- ── Face decal IDs per tier (free catalog assets) ─────────────────────────
-- These are stock Roblox face IDs that ship with the engine — always available
local FACE_IDS = {
    [0] = "rbxasset://textures/face.png",      -- classic derp / default
    [1] = "rbxasset://textures/face.png",      -- same but we'll tweak scale
    [2] = "rbxassetid://1369542387",           -- "Determined" face
    [3] = "rbxassetid://1369542387",           -- same for gym bro → sigma
    [4] = "rbxassetid://1369542387",           -- rizzler (better options via catalog)
    [5] = "rbxassetid://1369542387",           -- gigachad
}

-- ── Accessory catalog IDs per tier ────────────────────────────────────────
-- Using free Roblox default items only so no permission issues
-- Tier 3+: NPC Black Shades  (id 11884330)
-- Tier 5 : additionally add Roblox Crown (id 102611803)
local ACC_BY_TIER = {
    [0] = {},
    [1] = {},
    [2] = {},
    [3] = { 11884330 },           -- black shades
    [4] = { 11884330 },
    [5] = { 11884330, 102611803 },-- shades + crown
}

-- ── Rank index → tier mapping ─────────────────────────────────────────────
local function rankToTier(rankIndex)
    if rankIndex <= 1 then return 0
    elseif rankIndex == 2 then return 1
    elseif rankIndex == 3 then return 2
    elseif rankIndex <= 5 then return 3
    elseif rankIndex <= 7 then return 4
    else                       return 5
    end
end

-- ── Utility: tween a NumberValue ─────────────────────────────────────────
local function tweenValue(nv, target, duration)
    if duration <= 0 then
        nv.Value = target
    else
        TweenService:Create(nv, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = target}):Play()
    end
end

-- ── Apply body scales ────────────────────────────────────────────────────
local function applyBodyScale(humanoid, tier, duration)
    duration = duration or 1.2
    local scales = BODY_TIERS[tier] or BODY_TIERS[0]
    local map = {
        BodyHeightScale      = scales.height,
        BodyWidthScale       = scales.width,
        BodyDepthScale       = scales.depth,
        HeadScale            = scales.head,
        BodyProportionScale  = scales.prop,
    }
    for valueName, target in pairs(map) do
        local v = humanoid:FindFirstChild(valueName)
        if v then tweenValue(v, target, duration) end
    end
end

-- ── Apply skin color ────────────────────────────────────────────────────
local BODY_COLOR_PARTS = {
    "HeadColor", "LeftArmColor", "RightArmColor",
    "LeftLegColor", "RightLegColor", "TorsoColor"
}
local function applySkin(character, tier)
    local bc = character:FindFirstChildOfClass("BodyColors")
    if not bc then return end
    local col = SKIN_TIERS[tier] or SKIN_TIERS[0]
    for _, prop in ipairs(BODY_COLOR_PARTS) do
        bc[prop] = col
    end
end

-- ── Apply face ──────────────────────────────────────────────────────────
local function applyFace(character, tier)
    local head = character:FindFirstChild("Head")
    if not head then return end
    local face = head:FindFirstChild("face")
    if face and face:IsA("Decal") then
        face.Texture = FACE_IDS[tier] or FACE_IDS[0]
    end
end

-- ── Manage accessories ───────────────────────────────────────────────────
local InsertService = game:GetService("InsertService")
local addedAccIds   = {}  -- track what we've already loaded to avoid duplicates

local function applyAccessories(character, humanoid, tier)
    local wanted = ACC_BY_TIER[tier] or {}
    -- remove accessories from higher tier we've added that don't belong
    for _, acc in ipairs(character:GetChildren()) do
        if acc:IsA("Accessory") and acc:GetAttribute("ManagedBySigmaMgr") then
            local stillWanted = false
            for _, id in ipairs(wanted) do
                if acc:GetAttribute("SigmaAccId") == id then stillWanted = true ; break end
            end
            if not stillWanted then acc:Destroy() end
        end
    end
    -- add any missing
    for _, id in ipairs(wanted) do
        local already = false
        for _, acc in ipairs(character:GetChildren()) do
            if acc:IsA("Accessory") and acc:GetAttribute("SigmaAccId") == id then
                already = true ; break
            end
        end
        if not already then
            task.spawn(function()
                local ok, model = pcall(function()
                    return InsertService:LoadAsset(id)
                end)
                if ok and model then
                    local acc = model:FindFirstChildOfClass("Accessory")
                    if acc then
                        acc:SetAttribute("ManagedBySigmaMgr", true)
                        acc:SetAttribute("SigmaAccId", id)
                        acc.Parent = character
                        humanoid:AddAccessory(acc)
                    end
                    model:Destroy()
                end
            end)
        end
    end
end

-- ── Prestige face sparkle ─────────────────────────────────────────────────
local function applyPrestigeSparkle(character, prestige)
    local head = character:FindFirstChild("Head")
    if not head then return end
    local existing = head:FindFirstChild("SigmaFaceSparkle")
    if existing then existing:Destroy() end
    if prestige <= 0 then return end
    local p = Instance.new("ParticleEmitter")
    p.Name         = "SigmaFaceSparkle"
    p.Texture      = "rbxassetid://241629053"  -- sparkle star texture
    p.Color        = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
    })
    p.LightEmission = 0.9
    p.Size          = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.12 + prestige * 0.04),
        NumberSequenceKeypoint.new(1, 0),
    })
    p.Rate          = math.min(8 + prestige * 6, 40)
    p.Speed         = NumberRange.new(0.5, 1.5)
    p.Lifetime      = NumberRange.new(0.6, 1.2)
    p.SpreadAngle   = Vector2.new(180, 180)
    p.Parent        = head
end

-- ── Full refresh for a character ─────────────────────────────────────────
local lastTier     = -1
local lastPrestige = -1

local function refreshCharacter(character, rankIndex, prestige, animated)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local tier = rankToTier(rankIndex)
    local dur  = animated and 1.4 or 0

    if tier ~= lastTier then
        applyBodyScale(humanoid, tier, dur)
        applySkin(character, tier)
        applyFace(character, tier)
        applyAccessories(character, humanoid, tier)
        lastTier = tier
    end

    if prestige ~= lastPrestige then
        applyPrestigeSparkle(character, prestige)
        lastPrestige = prestige
    end
end

-- ── State tracking ────────────────────────────────────────────────────────
local currentRankIndex = 1
local currentPrestige  = 0

local function onCharacterAdded(character)
    -- Wait for humanoid to be fully loaded
    character:WaitForChild("HumanoidRootPart")
    character:WaitForChild("Humanoid")
    task.wait(0.1)
    lastTier     = -1  -- force full re-apply for new character
    lastPrestige = -1
    refreshCharacter(character, currentRankIndex, currentPrestige, false)
end

-- Connect to current and future characters
if player.Character then
    task.spawn(onCharacterAdded, player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- ── Listen for rank/prestige changes from UpdateUI ────────────────────────
local Ranks = require(ReplicatedStorage:WaitForChild("Ranks"))

-- Build a name → index lookup
local rankNameToIndex = {}
for i, r in ipairs(Ranks) do
    rankNameToIndex[r.name] = i
end

Remotes:WaitForChild("UpdateUI").OnClientEvent:Connect(function(data)
    local rankIndex = (rankNameToIndex[data.rank and data.rank.name] or 1)
    local prestige  = data.prestige or 0

    local changed = (rankIndex ~= currentRankIndex) or (prestige ~= currentPrestige)
    currentRankIndex = rankIndex
    currentPrestige  = prestige

    if changed then
        local char = player.Character
        if char then
            refreshCharacter(char, rankIndex, prestige, true)
        end
    end
end)
