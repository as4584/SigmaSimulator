-- Ranks.lua
-- Shared | All rank definitions, thresholds, and unlock descriptions

local Ranks = {
    { rank = 1,  name = "NPC",              emoji = "🤡", sigmaRequired = 0,          unlock = "Starting rank"                  },
    { rank = 2,  name = "Normie",           emoji = "😐", sigmaRequired = 500,        unlock = "New click animation"            },
    { rank = 3,  name = "Gym Bro",          emoji = "💪", sigmaRequired = 2000,       unlock = "First pet slot"                 },
    { rank = 4,  name = "Lone Wolf",        emoji = "🐺", sigmaRequired = 10000,      unlock = "Wolf forest area unlocks"       },
    { rank = 5,  name = "Sigma",            emoji = "😎", sigmaRequired = 50000,      unlock = "Aura effect on character"       },
    { rank = 6,  name = "Ohio Resident",    emoji = "🗿", sigmaRequired = 150000,     unlock = "Ohio portal opens"              },
    { rank = 7,  name = "Rizzler",          emoji = "🔥", sigmaRequired = 500000,     unlock = "Rizz aura + voice effect"       },
    { rank = 8,  name = "Gigachad",         emoji = "👑", sigmaRequired = 1000000,    unlock = "Gigachad character skin"        },
    { rank = 9,  name = "Skibidi God",      emoji = "⚡", sigmaRequired = 5000000,    unlock = "Skibidi dance emote"            },
    { rank = 10, name = "Sigma Multiverse", emoji = "🌌", sigmaRequired = 25000000,   unlock = "Prestige system unlocks"        },
    { rank = 11, name = "Final Form",       emoji = "☠️", sigmaRequired = 100000000,  unlock = "All cosmetics unlocked"         },
    { rank = 12, name = "THE GOAT",         emoji = "🏆", sigmaRequired = 0,          unlock = "Prestige 5+ required",  prestige = 5 },
}

return Ranks
