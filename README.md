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

1. **Title** → How to Play / Settings, or **Enter the Mall**
2. In the **mall corridor**, walk (or tap) into a store door with your friend
3. Move with the **left joystick**
4. Your **FRIEND** browses the store on their own — protect them
5. **Walk into clerks** to shove them away
6. **Hold LURE** and drag onto the floor, release to drop a coupon that draws clerks away
7. Defeat clerks → pick up **+XP** gems → level up → pick an upgrade
8. Survive until the timer ends with money left

First run shows a short **tutorial overlay** (skippable). Replay it anytime from **Settings**.

### Controls

| Control | Action |
|---------|--------|
| Left joystick | Move (works while aiming a coupon) |
| Hold LURE + drag | Place coupon; release to drop |
| Pause (top right) | Pause, legend, music/SFX toggles, quit |

---

## Stores (levels)

| Store | Duration | Starting budget | Starting weapon |
|-------|----------|-----------------|-----------------|
| Electronics Megamart | 2:00 | $120 | Price Tags |
| Fashion Boutique | 2:30 | $100 | Receipts |
| Grocery Warehouse | 3:00 | $80 | Shopping Bag |

**Unlocking:** Clear a store (timer ends, budget &gt; 0) to unlock the next. Progress is saved locally. Locked doors stay closed in the mall corridor until you clear the previous store.

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

- **SwiftUI** — menus, HUD, pause, upgrades, results, settings, tutorial
- **SpriteKit** — mall hub, arena, entities, combat, spawning
- **AVFoundation** — looping soundtrack + short SFX (`mall_survivors_theme.wav`, `sfx_*.wav`)
- **Landscape only** (iPhone & iPad)
- Target: iOS 18.6+

### Main layout

```
ShopSurvivors/
  ContentView.swift              # Screen router
  ShopSurvivorsApp.swift
  UI/                            # Title, hub, HUD, pause, settings, tutorial, results
  Game/
    GameScene.swift              # Core loop
    StoreHubScene.swift          # Walkable mall corridor
    Data/                        # Stores, weapons, clerks, session
    Entities/                    # Player, companion, clerks, projectiles, XP, coupon
    Systems/WalkAnimator.swift
    Audio/AudioManager.swift
    HUD/VirtualJoystick.swift
  Assets.xcassets/               # Pixel sprites + app icon
  Resources/                     # Theme + SFX wavs
scripts/generate_assets.py       # Regenerate pixel art
scripts/generate_sfx.py          # Regenerate SFX wavs
```

---

## Assets

Pixel-art sprites (player, friend, 4 clerks, walk cycles, projectiles, coupon, XP, shelves), title splash, and app icon. Regenerate gameplay sprites with:

```bash
python3 scripts/generate_assets.py
```

Regenerate sound effects with:

```bash
python3 scripts/generate_sfx.py
```

---

## Design notes (current build)

- Companion **does not follow** the player in-store; they browse shelves (in the mall hub they follow you)
- Shelves are **solid** (no walking through)
- Music/SFX use `.playback` (play even with the mute switch); toggles in Settings and pause
- HUD labels: `YOU`, `FRIEND`, `+XP`, `LURE`, weapon short names (labels stay readable when facing left)
- Pause menu includes a short legend plus music/SFX toggles
- Title has **How to Play** and **Settings**; first store entry can show coaching steps

---

## Run

Open `ShopSurvivors.xcodeproj` in Xcode, pick a landscape iPhone/iPad simulator or device, and run.
