-- Quests.lua
-- Shared | Sigma Quest definitions
-- req.type: "clicks" | "hatches" | "sigma" | "spins" | "evolutions" | "prestige" | "playtime"
-- reward.type: "rizz" | "sigma"

local Quests = {
    { id="click100",   name="First 100 Clicks",    emoji="👆", desc="Click 100 times",         req={type="clicks",     amount=100},     reward={type="rizz",  amount=15}  },
    { id="click1k",    name="Click Machine",        emoji="🤖", desc="Click 1,000 times",       req={type="clicks",     amount=1000},    reward={type="rizz",  amount=50}  },
    { id="click10k",   name="Sigma Grinder",        emoji="💪", desc="Click 10,000 times",      req={type="clicks",     amount=10000},   reward={type="rizz",  amount=200} },
    { id="hatch5",     name="Egg Cracker",          emoji="🥚", desc="Hatch 5 pets",            req={type="hatches",    amount=5},       reward={type="sigma", amount=500}  },
    { id="hatch25",    name="Pet Collector",        emoji="🎒", desc="Hatch 25 pets",           req={type="hatches",    amount=25},      reward={type="rizz",  amount=100} },
    { id="hatch100",   name="Pokemon? No, Sigma",   emoji="🏅", desc="Hatch 100 pets",          req={type="hatches",    amount=100},     reward={type="rizz",  amount=400} },
    { id="sigma10k",   name="Sigma Rising",         emoji="📈", desc="Earn 10,000 σ lifetime",  req={type="allsigma",   amount=10000},   reward={type="rizz",  amount=25}  },
    { id="sigma1m",    name="Sigma Millionaire",    emoji="💰", desc="Earn 1M σ lifetime",      req={type="allsigma",   amount=1000000}, reward={type="rizz",  amount=250} },
    { id="spin5",      name="Wheel Spinner",        emoji="🎡", desc="Spin the wheel 5 times",  req={type="spins",      amount=5},       reward={type="sigma", amount=2000} },
    { id="evolve1",    name="Evolution!",           emoji="🌟", desc="Evolve a pet once",       req={type="evolutions", amount=1},       reward={type="rizz",  amount=75}  },
    { id="prestige1",  name="First Rebirth",        emoji="⭐", desc="Prestige once",           req={type="prestige",   amount=1},       reward={type="rizz",  amount=200} },
    { id="play30m",    name="Dedicated Grinder",    emoji="⏰", desc="Play for 30 minutes",     req={type="playtime",   amount=1800},    reward={type="rizz",  amount=40}  },
    { id="play2h",     name="No Life Sigma",        emoji="😤", desc="Play for 2 hours total",  req={type="playtime",   amount=7200},    reward={type="rizz",  amount=150} },
}

return Quests
