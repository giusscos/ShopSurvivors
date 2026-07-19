# Game Center Setup — Version 1.0

Configure everything in **App Store Connect → your app → Features → Game Center**
(left sidebar under **GROWTH & MARKETING → Game Center**).

---

## Leaderboards

Create 3 **Classic Leaderboards** with the following settings:

| Field | Electronics | Fashion | Grocery |
|---|---|---|---|
| Reference Name | Electronics Budget | Fashion Budget | Grocery Budget |
| Leaderboard ID | `leaderboard_electronics_budget` | `leaderboard_fashion_budget` | `leaderboard_grocery_budget` |
| Score Format Type | Fixed Point | Fixed Point | Fixed Point |
| Decimal Places | 2 | 2 | 2 |
| Score Order | High to Low | High to Low | High to Low |

**Localization display names:**

| Leaderboard ID | Display Name |
|---|---|
| `leaderboard_electronics_budget` | Electronics Megamart |
| `leaderboard_fashion_budget` | Fashion Boutique |
| `leaderboard_grocery_budget` | Grocery Warehouse |

> Score format is Fixed Point with 2 decimals so that the raw integer score
> (budget × 100) displays as a dollar amount — e.g. 5045 → $50.45.

---

## Achievements

Create 5 achievements:

| Reference Name | Achievement ID | Points | Hidden |
|---|---|---|---|
| First Escape | `achievement_first_escape` | 10 | No |
| Mall Master | `achievement_mall_master` | 50 | No |
| Big Saver | `achievement_big_saver` | 25 | No |
| High Roller | `achievement_high_roller` | 25 | No |
| Veteran Shopper | `achievement_veteran` | 50 | No |

**Localization descriptions:**

| Achievement ID | Title | Description |
|---|---|---|
| `achievement_first_escape` | First Escape | Survive your first store run. |
| `achievement_mall_master` | Mall Master | Clear all three stores in the mall. |
| `achievement_big_saver` | Big Saver | Win a run with $80 or more budget remaining. |
| `achievement_high_roller` | High Roller | Reach player level 8 in a single run. |
| `achievement_veteran` | Veteran Shopper | Win 5 total runs. (shows progress in Game Center) |

---

## Xcode Capability

In Xcode → target → **Signing & Capabilities** → **+ Capability** → add **Game Center**.

---

## Score Logic (code reference)

- Score submitted = `Int(budget * 100)` (cents precision)
- Only submitted on a **win** (`endRun(won: true, ...)`)
- Achievements evaluated in `GameCenterManager.evaluateAchievements(budget:playerLevel:storeId:)`
- Total wins tracked in `UserDefaults` under key `gcTotalWins`

---

## Controller Mapping (Game Controllers capability — optional)

| Physical Input | Game Action |
|---|---|
| Left thumbstick | Move player |
| A / Cross | Deploy coupon lure ahead of player |
| Menu / Options | Toggle pause |

Controller IDs defined in `GameControllerManager.swift`.
Game Center IDs defined in `GameCenterManager.swift` (`GameCenterID` enum).
