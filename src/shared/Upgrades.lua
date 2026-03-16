-- Upgrades.lua
-- Shared | All upgrade definitions used by both server and client

local Upgrades = {
    -- ROOT
    { id = 1,  name = "Sigma Mindset",         path = "root",       cost = 100,     effect = "click_multiplier", value = 2   },

    -- LONE WOLF PATH
    { id = 2,  name = "Wolf Pack",              path = "lone_wolf",  cost = 500,     effect = "click_multiplier", value = 10  },
    { id = 3,  name = "Lone Wolf Mode",         path = "lone_wolf",  cost = 10000,   effect = "click_multiplier", value = 5   },
    { id = 4,  name = "Alpha Aura",             path = "lone_wolf",  cost = 2000,    effect = "click_multiplier", value = 50  },

    -- GRINDSET PATH
    { id = 5,  name = "Passive Income",         path = "grindset",   cost = 500,     effect = "idle_sigma",       value = 5   },
    { id = 6,  name = "Empire Builder",         path = "grindset",   cost = 2000,    effect = "idle_sigma",       value = 25  },
    { id = 7,  name = "Grindset Activated",     path = "grindset",   cost = 10000,   effect = "click_multiplier", value = 10  },

    -- ENDGAME (both paths required)
    { id = 8,  name = "Gigachad Transformation",path = "both",       cost = 50000,   effect = "click_multiplier", value = 50  },
    { id = 9,  name = "Final Form Sigma",       path = "both",       cost = 50000,   effect = "click_multiplier", value = 100 },
    { id = 10, name = "SIGMA CONVERGENCE",      path = "both",       cost = 100000,  effect = "click_multiplier", value = 1000 },
}

return Upgrades
