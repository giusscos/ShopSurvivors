# Shop Survivors

A landscape-only iOS prototype inspired by *Vampire Survivors*, set in a mall. You protect your friend’s **budget** from aggressive store clerks and their sales pitches.

---

## Concept

| Classic VS | Shop Survivors |
|------------|----------------|
| Health | **Budget ($)** |
| Enemies | **Store clerks** |
| Survive waves | **Survive a timed shopping run** |
| Weapons | Auto-weapons (price tags, receipts, laser, bag) |
| — | **LURE coupons** to distract clerks |

Clerks path toward your **friend** (companion). When they get close, they pitch and **drain budget**. If budget hits **$0**, you lose. If the **timer reaches 0:00** with budget left, you win and unlock the next store.

---

## How to play

1. **Title** → Enter the Mall → **Choose a store**
2. Move with the **left joystick**
3. Your **FRIEND** browses the store on their own — protect them
4. **Walk into clerks** to shove them away
5. **Hold LURE** and drag onto the floor, release to drop a coupon that draws clerks away
6. Defeat clerks → pick up **+XP** gems → level up → pick an upgrade
7. Survive until the timer ends with money left

### Controls

| Control | Action |
|---------|--------|
| Left joystick | Move (works while aiming a coupon) |
| Hold LURE + drag | Place coupon; release to drop |
| Pause (top right) | Pause, legend, music toggle, quit |

---

## Stores (levels)

| Store | Duration | Starting budget | Starting weapon |
|-------|----------|-----------------|-----------------|
| Electronics Megamart | 2:00 | $120 | Price Tags |
| Fashion Boutique | 2:30 | $100 | Receipts |
| Grocery Warehouse | 3:00 | $80 | Shopping Bag |

**Unlocking:** Clear a store (timer ends, budget &gt; 0) to unlock the next. Progress is saved locally.

---

## Clerks

| Type | Role |
|------|------|
| Pitcher | Basic drain |
| Closer | Slower, drains harder |
| Sprinter | Fast, low drain |
| Upseller | Extra drain when packed with other clerks |

---

## Weapons (auto)

| Short | Name | Behavior |
|-------|------|----------|
| TAG | Price Tags | Orbiting tags |
| RCP | Receipts | Projectiles at nearest clerks |
| LASER | Barcode Laser | Sweeping beam |
| BAG | Shopping Bag | Knockback pulse around you |

Unlocked / upgraded via XP level-up cards.

---

## Coupons (LURE)

- Hold the orange **HOLD LURE** button and drag into the arena
- Release to drop; clerks in range path to the coupon for a few seconds
- Cooldown between uses (can be improved via upgrades)

---

## Upgrades (on level-up)

- New weapon / weapon level
- Move speed
- Faster coupons
- Companion willpower (slower budget drain)
- Small budget refill

---

## Tech stack

- **SwiftUI** — menus, HUD, pause, upgrades, results
- **SpriteKit** — arena, entities, combat, spawning
- **AVFoundation** — looping retro soundtrack (`mall_survivors_theme.wav`)
- **Landscape only** (iPhone & iPad)
- Target: iOS 18.6+

### Main layout

```
ShopSurvivors/
  ContentView.swift              # Screen router
  ShopSurvivorsApp.swift
  UI/                            # Title, level select, HUD, pause, results
  Game/
    GameScene.swift              # Core loop
    Data/                        # Stores, weapons, clerks, session
    Entities/                    # Player, companion, clerks, projectiles, XP, coupon
    Systems/WalkAnimator.swift
    Audio/AudioManager.swift
    HUD/VirtualJoystick.swift
  Assets.xcassets/               # Pixel sprites + app icon
  Resources/mall_survivors_theme.wav
scripts/generate_assets.py       # Regenerate pixel art
```

---

## Assets

Pixel-art sprites (player, friend, 4 clerks, walk cycles, projectiles, coupon, XP, shelves), title splash, and app icon. Regenerate gameplay sprites with:

```bash
python3 scripts/generate_assets.py
```

---

## Design notes (current build)

- Companion **does not follow** the player; they browse shelves
- Shelves are **solid** (no walking through)
- Music uses `.playback` (plays even with the mute switch); toggle in pause
- HUD labels: `YOU`, `FRIEND`, `+XP`, `LURE`, weapon short names
- Pause menu includes a short legend and music toggle

---

## Run

Open `ShopSurvivors.xcodeproj` in Xcode, pick a landscape iPhone/iPad simulator or device, and run.
