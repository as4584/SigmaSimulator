-- DailyRewards.lua
-- Shared | 7-day daily reward cycle (loops back to day 1 after day 7)

local DailyRewards = {
    { day=1, label="💎 +10 Rizz",          reward={type="rizz",  amount=10}    },
    { day=2, label="😎 +1,000 σ",          reward={type="sigma", amount=1000}  },
    { day=3, label="💎 +25 Rizz",          reward={type="rizz",  amount=25}    },
    { day=4, label="😎 +5,000 σ",          reward={type="sigma", amount=5000}  },
    { day=5, label="💎 +50 Rizz",          reward={type="rizz",  amount=50}    },
    { day=6, label="😎 +25,000 σ",         reward={type="sigma", amount=25000} },
    { day=7, label="💎 +100 Rizz 🎉",      reward={type="rizz",  amount=100}   },
}

return DailyRewards
