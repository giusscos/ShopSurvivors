# Shop Survivors

A landscape-only iOS game inspired by *Vampire Survivors*, set in a mall. You protect your friend’s **budget** from aggressive store clerks and their sales pitches.

**Price:** $2.99 (premium, no IAP)

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

Clear all three campaign stores to unlock **Midnight Mall** — an endless run scored by survival time.

---

## How to play

1. **First launch** shows a short **manga lore intro** (skip anytime; replay from Settings)
2. **Title** → How to Play / Settings, or **Enter the Mall**
3. In the **mall corridor**, walk (or tap) into a store door with your friend
4. Move with the **left joystick** (or a connected game controller)
5. Your **FRIEND** browses the store on their own — protect them
6. **Walk into clerks** to shove them away
7. **Hold LURE** and drag onto the floor, release to drop a coupon that draws clerks away
8. Defeat clerks → pick up **+XP** gems → level up → pick an upgrade
9. Survive until the timer ends with money left (or last as long as you can in Endless)

First store run shows a short **tutorial overlay** (skippable). Replay it anytime from **Settings**.

### Touch controls

| Control | Action |
|---------|--------|
| Left joystick | Move (works while aiming a coupon) |
| Hold LURE + drag | Place coupon; release to drop |
| Pause (top right) | Pause, legend, music/SFX toggles, quit |

### Game controller

When an extended gamepad is connected, on-screen move/LURE controls hide. Mapping:

| Physical input | Action |
|----------------|--------|
| Left thumbstick | Move |
| A / Cross | Deploy a coupon lure ahead of the player |
| Menu / Options | Toggle pause |

---

## Stores (levels)

| Store | Duration | Starting budget | Starting weapon |
|-------|----------|-----------------|-----------------|
| Electronics Megamart | 2:00 | $120 | Price Aura |
| Fashion Boutique | 2:30 | $100 | Receipts |
| Grocery Warehouse | 3:00 | $80 | Shopping Bag |
| Midnight Mall (Endless) | Until wallet wiped | $100 | Price Aura |

**Unlocking:** Clear a store (timer ends, budget &gt; 0) to unlock the next. Clear Grocery to unlock Endless. Progress and **local best scores** are saved on device. Locked doors stay closed until you clear the previous store.

---

## Game Center

Sign in happens on launch. Wins submit a per-store high score and evaluate achievements. Local bests still update offline.

**Leaderboards** (campaign score = remaining budget in cents, e.g. `$50.45` → `5045`; Endless = whole seconds survived):

| Store | Leaderboard ID |
|-------|----------------|
| Electronics Megamart | `leaderboard_electronics_budget` |
| Fashion Boutique | `leaderboard_fashion_budget` |
| Grocery Warehouse | `leaderboard_grocery_budget` |
| Midnight Mall | `leaderboard_endless_survival` |

Open a store’s board from the **results** screen, or the full Game Center dashboard from the **mall hub**.

**Achievements:**

| ID | Title | Unlock |
|----|-------|--------|
| `achievement_first_escape` | First Escape | Survive your first store run |
| `achievement_mall_master` | Mall Master | Clear Grocery (all three campaign stores) |
| `achievement_big_saver` | Big Saver | Win with $80+ budget remaining |
| `achievement_high_roller` | High Roller | Reach player level 8 in a run |
| `achievement_veteran` | Veteran Shopper | Win 5 runs total (progress shown) |
| `achievement_coupon_king` | Coupon King | Deploy 10 LUREs in a single run |
| `achievement_night_owl` | Night Owl | Survive 2:00 in Midnight Mall |

ASC setup checklist (IDs, score format, art): `metadata/1.0/game-center-setup.md`. Leaderboard/achievement images live under `Art/`.

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
| AURA | Price Aura | Small damage ring around you |
| RCP | Receipts | Projectiles at nearest clerks |
| LASER | Barcode Laser | Sweeping beam |
| BAG | Shopping Bag | Knockback pulse around you |

Unlocked / upgraded via XP level-up cards.

---

## Coupons (LURE)

- Hold the orange **HOLD LURE** button and drag into the arena
- On controller, press **A** to drop a lure ahead of the player
- Release to drop; clerks in range path to the coupon for a few seconds
- Cooldown between uses (can be improved via upgrades)

---

## Upgrades (on level-up)

- New weapon / weapon level
- Move speed
- Faster coupons
- Companion willpower (slower budget drain)
- Small budget refill

Multi-level-ups queue separate upgrade choices so you never lose a pick.

---

## Tech stack

- **SwiftUI** — menus, HUD, pause, upgrades, results, settings, tutorial, lore intro
- **SpriteKit** — mall hub, arena, entities, combat, spawning
- **GameKit** — Game Center auth, leaderboards, achievements
- **GameController** — extended gamepad input
- **AVFoundation** — looping soundtrack + short SFX (`mall_survivors_theme.wav`, `sfx_*.wav`)
- **Landscape only** (iPhone & iPad)
- Target: iOS 18.6+
- Privacy Manifest: `PrivacyInfo.xcprivacy` (UserDefaults only; no tracking)

### Main layout

```
ShopSurvivors/
  ContentView.swift              # Screen router + background pause
  ShopSurvivorsApp.swift
  PrivacyInfo.xcprivacy
  UI/                            # Title, hub, HUD, pause, settings, tutorial, lore intro, results
  Game/
    GameScene.swift              # Core loop
    StoreHubScene.swift          # Walkable mall corridor
    Data/                        # Stores, weapons, clerks, session
    Entities/                    # Player, companion, clerks, projectiles, XP, coupon
    Systems/WalkAnimator.swift
    Systems/Haptics.swift
    Audio/AudioManager.swift
    HUD/VirtualJoystick.swift
    GameCenter/                  # Game Center + game controller managers
  Assets.xcassets/               # Pixel sprites + app icon
  Resources/                     # Theme + SFX wavs
Art/                             # Game Center leaderboard & achievement art (ASC)
metadata/1.0/                    # ASC setup notes
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
- Shelves are **solid** (no walking through); layout density varies by store
- Music/SFX use `.playback` (play even with the mute switch); toggles in Settings and pause
- HUD labels: `YOU`, `FRIEND`, `+XP`, `LURE` (labels stay readable when facing left)
- Pause menu includes a short legend plus music/SFX toggles (controller mapping when a pad is connected)
- Title uses **title_splash** art; first store entry can show coaching steps
- First launch plays a **4-panel manga lore intro** (vignette + light motion); skipped after that, replayable in Settings
- SpriteKit views request **120 fps** with real delta time (ProMotion-safe)
- Mid-run backgrounding **auto-pauses**
- Game Center scores submit on campaign wins / Endless finishes; local bests always save
- Touch joystick/LURE hide while a controller is connected

---

## App Store Connect checklist

See `metadata/1.0/app-store-checklist.md`.

---

## Run

Open `ShopSurvivors.xcodeproj` in Xcode, pick a landscape iPhone/iPad simulator or device, and run.

Game Center auth, leaderboards, and achievements need a **signed-in device** (or Game Center–capable environment); the simulator alone is not enough for a full check.
