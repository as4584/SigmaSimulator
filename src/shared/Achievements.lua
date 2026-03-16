-- Achievements.lua
-- Shared | Achievement badge definitions
-- trigger.type: "clicks" | "hatches" | "prestige" | "total_sigma" | "ascension"
--               "total_playtime" | "all_pets" | "rarity" | "evolution"

local Achievements = {
    { id="first_click",     name="First Click!",         emoji="👆", desc="Click for the first time",          trigger={type="clicks",        amount=1},           reward={type="rizz",  amount=5}    },
    { id="click500",        name="Clicker Awakening",    emoji="🖱️", desc="Click 500 times",                   trigger={type="clicks",        amount=500},         reward={type="rizz",  amount=20}   },
    { id="first_pet",       name="New Best Friend",      emoji="🐾", desc="Hatch your first pet",              trigger={type="hatches",       amount=1},           reward={type="rizz",  amount=10}   },
    { id="legendary_pet",   name="LEGENDARY PULL!",      emoji="👑", desc="Hatch a Legendary pet",             trigger={type="rarity",        rarity="Legendary"}, reward={type="rizz",  amount=50}   },
    { id="first_prestige",  name="First Rebirth",        emoji="⭐", desc="Prestige for the first time",       trigger={type="prestige",      amount=1},           reward={type="sigma", amount=5000}  },
    { id="prestige3",       name="Sigma Veteran",        emoji="🔱", desc="Reach Prestige 3",                  trigger={type="prestige",      amount=3},           reward={type="rizz",  amount=150}  },
    { id="prestige5",       name="The Ascending One",    emoji="🔥", desc="Reach Prestige 5 (Ascension unlocked!)", trigger={type="prestige", amount=5},           reward={type="rizz",  amount=300}  },
    { id="sigma100k",       name="100K Club",            emoji="💯", desc="Earn 100,000 σ total",              trigger={type="total_sigma",   amount=100000},      reward={type="rizz",  amount=100}  },
    { id="sigma10m",        name="Sigma Elite",          emoji="🌌", desc="Earn 10,000,000 σ total",           trigger={type="total_sigma",   amount=10000000},    reward={type="rizz",  amount=500}  },
    { id="ascension1",      name="True Sigma",           emoji="✨", desc="Ascend for the first time",         trigger={type="ascension",     amount=1},           reward={type="rizz",  amount=1000} },
    { id="all_pets",        name="Gotta Catch Em All",   emoji="🏅", desc="Own every pet at least once",       trigger={type="all_pets"},                          reward={type="rizz",  amount=500}  },
    { id="evolution1",      name="Evolution!",           emoji="🌟", desc="Evolve your first pet",             trigger={type="evolution",     amount=1},           reward={type="rizz",  amount=75}   },
    { id="hours1",          name="Addicted",             emoji="⏰", desc="Play for 1 hour total",             trigger={type="total_playtime",amount=3600},         reward={type="rizz",  amount=100}  },
    { id="hours5",          name="Sigma Life",           emoji="😤", desc="Play for 5 hours total",            trigger={type="total_playtime",amount=18000},        reward={type="rizz",  amount=400}  },
}

return Achievements
