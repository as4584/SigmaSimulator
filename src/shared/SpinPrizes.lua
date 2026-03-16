-- SpinPrizes.lua
-- Shared | Rizz Spin Wheel prize table (8 segments)
-- weight out of 100 (must not exceed 100 total)

local SpinPrizes = {
    { label="+10 Rizz",     type="rizz",  amount=10,    weight=30, emoji="💎", color={255,100,100} },
    { label="+25 Rizz",     type="rizz",  amount=25,    weight=20, emoji="💎", color={255,170,50}  },
    { label="+50 Rizz",     type="rizz",  amount=50,    weight=15, emoji="💎", color={255,230,50}  },
    { label="+100 Rizz",    type="rizz",  amount=100,   weight=10, emoji="💎", color={100,230,100} },
    { label="+500 σ",       type="sigma", amount=500,   weight=10, emoji="😎", color={60,150,255}  },
    { label="+5,000 σ",     type="sigma", amount=5000,  weight=8,  emoji="😎", color={150,80,255}  },
    { label="+25,000 σ",    type="sigma", amount=25000, weight=5,  emoji="🏆", color={255,100,200} },
    { label="2x Boost 3m",  type="boost", amount=180,   weight=2,  emoji="⚡", color={100,230,220} },
}

return SpinPrizes
