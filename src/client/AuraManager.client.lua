-- AuraManager.client.lua
-- Applies prestige aura (PointLight + ParticleEmitter) to the local character.
-- God Mode overrides with a blazing gold aura for its full duration.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player  = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PRESTIGE_AURAS = {
    [1] = { color = Color3.fromRGB(200, 200, 230), brightness = 0.4, rate = 8    },  -- faint white
    [2] = { color = Color3.fromRGB(160,  40, 255), brightness = 0.7, rate = 20   },  -- purple
    [3] = { color = Color3.fromRGB(255, 200,   0), brightness = 1.2, rate = 40   },  -- gold
    [4] = { color = Color3.fromRGB(255,  60,  60), brightness = 1.8, rate = 65   },  -- blazing red
    [5] = { color = Color3.fromRGB(  0, 240, 255), brightness = 2.5, rate = 100  },  -- cyan legendary
}
local GOD_AURA = { color = Color3.fromRGB(255, 210, 0), brightness = 6.0, rate = 200 }

local currentLight    = nil
local currentParticle = nil
local godModeOn       = false
local lastPrestige    = 0

local function clearAura()
    if currentLight    and currentLight.Parent    then currentLight:Destroy()    end
    if currentParticle and currentParticle.Parent then currentParticle:Destroy() end
    currentLight = nil ; currentParticle = nil
end

local function applyAura(aura)
    clearAura()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local light = Instance.new("PointLight")
    light.Name       = "SigmaAuraLight"
    light.Color      = aura.color
    light.Brightness = aura.brightness
    light.Range      = 18
    light.Parent     = hrp
    currentLight     = light

    local pe = Instance.new("ParticleEmitter")
    pe.Color         = ColorSequence.new(aura.color)
    pe.Rate          = aura.rate
    pe.Speed         = NumberRange.new(2, 6)
    pe.Lifetime      = NumberRange.new(0.4, 1.2)
    pe.Size          = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.35),
        NumberSequenceKeypoint.new(1, 0),
    })
    pe.LightEmission    = 0.9
    pe.LightInfluence   = 0.1
    pe.Parent           = hrp
    currentParticle     = pe
end

local function refreshAura()
    if godModeOn then
        applyAura(GOD_AURA)
    elseif lastPrestige > 0 then
        local aura = PRESTIGE_AURAS[math.min(lastPrestige, 5)]
        if aura then applyAura(aura) end
    else
        clearAura()
    end
end

-- Re-apply after character respawn
player.CharacterAdded:Connect(function()
    task.wait(1.5)
    currentLight    = nil
    currentParticle = nil
    refreshAura()
end)

-- Track prestige and apply aura each time it changes
Remotes:WaitForChild("UpdateUI").OnClientEvent:Connect(function(data)
    if godModeOn then return end
    local p = data.prestige or 0
    if p == lastPrestige then return end   -- no change
    lastPrestige = p
    refreshAura()
end)

-- God Mode active → blazing gold override
Remotes:WaitForChild("GodModeActive").OnClientEvent:Connect(function()
    godModeOn = true
    applyAura(GOD_AURA)
end)

-- God Mode ended → restore prestige aura (or clear if prestige 0)
Remotes:WaitForChild("GodModeEnded").OnClientEvent:Connect(function()
    godModeOn = false
    clearAura()
    refreshAura()
end)
