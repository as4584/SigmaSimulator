-- Eggs.lua
-- Shared | Three egg types with rarity weight tables
-- weights: roll 1-100; Legendary first, then Rare, rest = Common

local Eggs = {
    {
        id      = "common",
        name    = "Common Egg",
        emoji   = "🥚",
        cost    = 5,   -- Rizz Tokens
        color   = Color3.fromRGB(200, 200, 200),
        -- percentages (must sum to 100)
        weights = { Legendary = 5, Rare = 25, Common = 70 },
    },
    {
        id      = "rare",
        name    = "Rare Egg",
        emoji   = "💙",
        cost    = 15,
        color   = Color3.fromRGB(80, 140, 255),
        weights = { Legendary = 15, Rare = 55, Common = 30 },
    },
    {
        id      = "legendary",
        name    = "Legendary Egg",
        emoji   = "🌟",
        cost    = 50,
        color   = Color3.fromRGB(255, 170, 0),
        weights = { Legendary = 60, Rare = 35, Common = 5 },
    },
}

return Eggs
