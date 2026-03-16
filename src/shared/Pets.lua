-- Pets.lua
-- Shared | All pet definitions. Three tiers: Common / Rare / Legendary
-- Hatched via Eggs.lua rarity tables, no individual eggCost here.
-- evolvedSigmaPerSec: income when the pet is evolved (3 dupes → 1 evolved copy, 2x income)
-- evolvedEmoji: shown in UI when this pet is evolved

local Pets = {
    -- ── Common ───────────────────────────────────────────────────────────
    { id=1, name="NPC Dog",          rarity="Common",    sigmaPerSec=1,     emoji="🐶", evolvedName="Chad Dog",            evolvedSigmaPerSec=2,     evolvedEmoji="🐕" },
    { id=2, name="Sigma Chad",       rarity="Common",    sigmaPerSec=4,     emoji="😎", evolvedName="Ultra Chad",          evolvedSigmaPerSec=8,     evolvedEmoji="🗿" },
    { id=3, name="Brainrot Hamster", rarity="Common",    sigmaPerSec=10,    emoji="🐹", evolvedName="Omega Hamster",       evolvedSigmaPerSec=20,    evolvedEmoji="🐁" },
    -- ── Rare ─────────────────────────────────────────────────────────────
    { id=4, name="Lone Wolf",        rarity="Rare",      sigmaPerSec=35,    emoji="🐺", evolvedName="Alpha Wolf",          evolvedSigmaPerSec=70,    evolvedEmoji="🌕" },
    { id=5, name="Ohio Serpent",     rarity="Rare",      sigmaPerSec=90,    emoji="🐍", evolvedName="Ohio Hydra",          evolvedSigmaPerSec=180,   evolvedEmoji="🐲" },
    { id=6, name="Gigachad Eagle",   rarity="Rare",      sigmaPerSec=250,   emoji="🦅", evolvedName="Sigma Phoenix",       evolvedSigmaPerSec=500,   evolvedEmoji="🔥" },
    -- ── Legendary ────────────────────────────────────────────────────────
    { id=7, name="Sigma Dragon",     rarity="Legendary", sigmaPerSec=1000,  emoji="👑", evolvedName="True Sigma Dragon",   evolvedSigmaPerSec=2000,  evolvedEmoji="🐉" },
    { id=8, name="Rizz God",         rarity="Legendary", sigmaPerSec=3000,  emoji="💜", evolvedName="Absolute Rizz God",  evolvedSigmaPerSec=6000,  evolvedEmoji="💫" },
    { id=9, name="Brainrot God",     rarity="Legendary", sigmaPerSec=10000, emoji="🌌", evolvedName="Brainrot Deity",     evolvedSigmaPerSec=20000, evolvedEmoji="☄️" },
}

return Pets
