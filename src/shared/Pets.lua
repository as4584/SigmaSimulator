-- Pets.lua
-- Shared | All pet definitions. Three tiers: Common / Rare / Legendary
-- Hatched via Eggs.lua rarity tables, no individual eggCost here.

local Pets = {
    -- ── Common ───────────────────────────────────────────────────────────
    { id = 1, name = "NPC Dog",          rarity = "Common",    sigmaPerSec = 1,     emoji = "🐶" },
    { id = 2, name = "Sigma Chad",       rarity = "Common",    sigmaPerSec = 4,     emoji = "😎" },
    { id = 3, name = "Brainrot Hamster", rarity = "Common",    sigmaPerSec = 10,    emoji = "🐹" },
    -- ── Rare ─────────────────────────────────────────────────────────────
    { id = 4, name = "Lone Wolf",        rarity = "Rare",      sigmaPerSec = 35,    emoji = "🐺" },
    { id = 5, name = "Ohio Serpent",     rarity = "Rare",      sigmaPerSec = 90,    emoji = "🐍" },
    { id = 6, name = "Gigachad Eagle",   rarity = "Rare",      sigmaPerSec = 250,   emoji = "🦅" },
    -- ── Legendary ────────────────────────────────────────────────────────
    { id = 7, name = "Sigma Dragon",     rarity = "Legendary", sigmaPerSec = 1000,  emoji = "👑" },
    { id = 8, name = "Rizz God",         rarity = "Legendary", sigmaPerSec = 3000,  emoji = "💜" },
    { id = 9, name = "Brainrot God",     rarity = "Legendary", sigmaPerSec = 10000, emoji = "🌌" },
}

return Pets
