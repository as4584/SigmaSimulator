# Sigma Simulator 😎

A Roblox brainrot idle clicker game built with Rojo + VS Code.

**Current Version**: V4  
**GitHub**: https://github.com/as4584/SigmaSimulator.git  
**DataStore**: `SigmaSimV4`

---

## 🎮 Game Systems (V4)

| System | Status |
|--------|--------|
| Click → earn Sigma (4-tier crits) | ✅ |
| Rank ladder (12 ranks) | ✅ |
| Upgrade tree (10 upgrades) | ✅ |
| Pet system (hatch, equip, evolve) | ✅ |
| Egg shop (3 eggs, rarity pool) | ✅ |
| Spin wheel (8 prizes, free/paid) | ✅ |
| Daily rewards (10-day streak) | ✅ |
| Quests (8 quests) | ✅ |
| Achievements (12 achievements) | ✅ |
| Free reward slots (3 timed) | ✅ |
| Sigma Duels (1v1 click race) | ✅ |
| Prestige + Ascension | ✅ |
| God mode flash | ✅ |
| Leaderboard (top 5) | ✅ |
| Co-op boost (+20%) | ✅ |
| Events (6 types, world Parts) | ✅ |
| Offline earnings (up to 4h) | ✅ |
| Tap-anywhere input (no click button) | ✅ |
| Space key support | ✅ |

## 🐛 Known Issues (as of Chat 2)

- **Floating sigma numbers not appearing** after taps — clicks work (sigma accrues, GodMode fires) but `spawnFloat` and `spawnTapRipple` may be blocked by `panelHost` frame intercepting input
- **Nav bar is horizontal bottom bar** — 10 buttons, too cluttered on mobile. Planned: vertical right-side rail, icon-only pills

---


Hey! This is your guide for adding maps, models, pets and accessories to the game. You handle the creative 3D side — I handle wiring it into the code. Here's everything you need to know.

---

## 📁 Project Structure

```
SigmaSimulator/
├── src/
│   ├── server/        ← Alex's code — don't touch
│   ├── client/        ← Alex's code — don't touch
│   └── shared/        ← Data tables (Pets, Eggs, Ranks, etc.) — Alex's side
├── assets/
│   ├── models/        ← PUT WORLD MODELS HERE
│   ├── zones/         ← PUT FULL ZONES / MAPS HERE
│   ├── accessories/   ← PUT CHARACTER ACCESSORIES HERE
│   ├── pets/          ← PUT PET MODELS HERE (the 3D pet mesh/rig)
│   └── ui/            ← PUT UI ASSETS / ICONS HERE
├── default.project.json   ← wires everything into Studio via Rojo
└── README.md
```

---

## 🏗️ Step 0 — First-Time Setup (Do This Once)

### Install Rojo (the tool that syncs Studio ↔ this repo)

1. Go to: [https://github.com/rojo-rbx/rojo/releases](https://github.com/rojo-rbx/rojo/releases)
2. Download `rojo-7.6.1-windows-x86_64.zip` (or Mac version)
3. Unzip it and put the `rojo.exe` somewhere easy (like `C:\Rojo\`)
4. Add that folder to your PATH, OR just run it from that folder in terminal

### Install the Rojo plugin in Roblox Studio

1. Open Roblox Studio → Toolbox → search "Rojo"
2. Install the official Rojo plugin by Roblox

### Clone this repo (if you haven't already)

```bash
git clone https://github.com/as4584/SigmaSimulator.git
cd SigmaSimulator
```

---

## 🔁 Every Time You Work (The Routine)

```bash
# 1. Always pull first before you start anything
git pull

# 2. Start the Rojo sync server
rojo serve

# 3. In Roblox Studio: Rojo plugin → Connect → localhost:34872

# 4. Build your stuff in Studio — changes sync live!

# 5. When done, back in terminal:
git add .
git commit -m "describe what you added"
git push
```

---

## 🌍 Adding a New World Model or Zone

1. **Build your model** in Roblox Studio
2. **Group it** — select everything → right-click → `Group` (it becomes one `Model`)
3. **Name the Model clearly** — e.g. `OhioZone`, `SigmaForest`, `RizzPalace`, `SkibidiTower`
4. **Right-click the Model** in the Explorer panel → `Save to File...`
5. Save as `.rbxmx` into `assets/zones/YourModelName.rbxmx`
6. Message Alex with:
   - The exact file name
   - Where in the map it should appear (coords, or "replace the main island", etc.)
   - Any special effects (music, ambient sound, rank requirement to enter)

**Alex will then:**
- Add it to `default.project.json` so it shows in the world
- Wire any triggers (touch boundary → unlock zone, play audio, etc.)

---

## 🐾 Adding a New Pet Model (3D Mesh)

Pet stats and hatching odds are in the code — you just supply the 3D model.

1. Build your pet as a **Model** in Studio (can be animated or static)
2. Name it exactly matching the pet's name in the game, e.g.: `Lone Wolf`, `Sigma Dragon`
   - **Check the exact names in** `src/shared/Pets.lua`
3. Export to `assets/pets/PetName.rbxmx`
4. Message Alex the name + any notes (idle animation, scale, color theme)

**Naming convention:**
```
assets/pets/NPC Dog.rbxmx
assets/pets/Sigma Chad.rbxmx
assets/pets/Brainrot Hamster.rbxmx
assets/pets/Lone Wolf.rbxmx
assets/pets/Ohio Serpent.rbxmx
assets/pets/Gigachad Eagle.rbxmx
assets/pets/Sigma Dragon.rbxmx
assets/pets/Rizz God.rbxmx
assets/pets/Brainrot God.rbxmx
```

If you make a pet for the **evolved form** (after 3 duplicates in-game), suffix it with `_EVO`:
```
assets/pets/Sigma Dragon_EVO.rbxmx
```

---

## 👗 Adding Accessories / Cosmetics

1. In Studio, create an `Accessory` instance:
   - Add a `Part` (shaped however you want)
   - Add an `Attachment` to the Part named **exactly** `Handle` (Roblox requires this)
   - Group the Part under an `Accessory` object
2. Name the Accessory clearly: `SigmaHat`, `OhioAura`, `RizzCrown`
3. Export to `assets/accessories/YourAccessoryName.rbxmx`
4. Message Alex:
   - The file name
   - What rank or prestige unlocks it (e.g. "unlocks at Rizzler rank" or "prestige 3")
   - Where it attaches (hat, back, shoulder, etc.)

---

## 🎨 Adding UI Icons / Images

If you made a custom icon, badge image, or background art:

1. Upload the image to Roblox as a Decal/Image (via Studio → Asset Manager → Import)
2. Record the **Asset ID** that Roblox gives it (e.g. `rbxassetid://123456789`)
3. Save the original file to `assets/ui/YourImageName.png`
4. Message Alex the Asset ID and where it should be used

---

## 🗺️ Suggesting a New Egg or Area Theme

If you have a creative idea for a new egg type, zone theme, or pet concept:

1. Write it up in a new file: `assets/ideas/YourIdea.md`
2. Include:
   - Pet name + what emoji vibe it has
   - Zone name + what it looks/feels like
   - Any gameplay hook (special mechanic, event, etc.)
3. Push it and tag Alex

---

## ✅ Rules (Important!)

| ✅ Do | ❌ Don't |
|-------|---------|
| Edit files in `assets/` | Touch anything in `src/` |
| Name models clearly | Use vague names like `Model1` |
| Pull before you start | Push without pulling first |
| Message Alex before major moves | Delete or rename someone else's file |
| Use `.rbxmx` format for models | Use `.rbxl` (that's a full place file) |

---

## 🐛 Troubleshooting

| Problem | Fix |
|---------|-----|
| Studio won't connect to Rojo | Make sure `rojo serve` is running in terminal first |
| My model disappeared after `git pull` | You probably had a conflict — message Alex |
| "Rojo plugin not found" | Re-install it from the Toolbox (search "Rojo") |
| Git says "nothing to commit" | Your file might not have saved in Studio — try Save to File again |
| Git merge conflict | Don't try to fix it yourself — message Alex |

---

## 🎮 Current Pet List (Reference)

| ID | Name | Rarity | σ/sec | Evolved σ/sec |
|----|------|--------|-------|---------------|
| 1 | NPC Dog | Common | 1 | 2 |
| 2 | Sigma Chad | Common | 4 | 8 |
| 3 | Brainrot Hamster | Common | 10 | 20 |
| 4 | Lone Wolf | Rare | 35 | 70 |
| 5 | Ohio Serpent | Rare | 90 | 180 |
| 6 | Gigachad Eagle | Rare | 250 | 500 |
| 7 | Sigma Dragon | Legendary | 1,000 | 2,000 |
| 8 | Rizz God | Legendary | 3,000 | 6,000 |
| 9 | Brainrot God | Legendary | 10,000 | 20,000 |

Evolution requires **3 copies** of the same pet.

---

## 📋 Current Feature List (For Reference)

- **Egg Hatching** — 3 egg tiers (Common / Rare / Legendary)
- **Reroll** — spend half the egg cost to re-roll your last result
- **Auto-Roll** — server-side loop rolls while you walk around freely
- **Pet Evolution** — merge 3 copies → 1 evolved pet with 2x income
- **Prestige** — reset at 10,000σ for a permanent multiplier boost
- **Ascension** — at Prestige 5, do a True Reset for a permanent 2x^N multiplier
- **Offline Earning** — earn sigma while offline (up to 4 hours, based on pet income)
- **Rizz Spin Wheel** — spin for prizes; free every 6 hours or cost 5 Rizz
- **Daily Rewards** — 7-day streak calendar with escalating rewards
- **Sigma Quests** — 10 challenge quests with Rizz/Sigma rewards
- **Achievements** — 10 milestone badges with bonus rewards
- **Free Rewards Menu** — 3 time-gated free reward slots (15min / 1hr / 24hr)
- **AFK Rewards** — +15 Rizz every 5 minutes you stay in the game
- **Duels** — 1v1 click battles with sigma at stake
- **God Mode** — click 20 times in 5 seconds for 100x for 10s
- **Events** — server-wide random events (Sigma Rush, Ohio Storm, Rizz Rain, etc.)
- **Leaderboard** — top 5 sigma earners
- **Co-op Boost** — +20% sigma when 2+ players in server

---

Any questions just message Alex! 😎
