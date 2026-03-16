-- Events.lua
-- Shared | All random event definitions

local Events = {
    { id = 1, name = "Sigma Rush",     emoji = "🔥", duration = 30, effect = "sigma_multiplier", value = 3,   description = "3x all sigma gain!"         },
    { id = 2, name = "Ohio Storm",     emoji = "🌪️", duration = 45, effect = "sigma_multiplier", value = 2,   description = "Ohio has arrived. 2x sigma." },
    { id = 3, name = "Rizz Rain",      emoji = "💎", duration = 20, effect = "rizz_tokens",      value = 10,  description = "Free Rizz Tokens falling!"   },
    { id = 4, name = "Gigachad Visit", emoji = "👑", duration = 60, effect = "bonus_clicks",     value = 500, description = "Click the Gigachad for bonus!"},
    { id = 5, name = "NPC Invasion",   emoji = "☠️", duration = 30, effect = "npc_targets",      value = 20,  description = "Defeat NPCs for sigma!"      },
    { id = 6, name = "Sigma Lottery",  emoji = "🎰", duration = 10, effect = "lottery_jackpot",  value = 5000,description = "Click fast to win jackpot!"  },
}

return Events
