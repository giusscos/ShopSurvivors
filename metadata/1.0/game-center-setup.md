# Game Center Setup — Version 1.0

Configure everything in **App Store Connect → your app → Features → Game Center**
(left sidebar under **GROWTH & MARKETING → Game Center**).

---

## Leaderboards

Create **4 Classic Leaderboards** with the following settings:

| Field | Electronics | Fashion | Grocery | Endless |
|---|---|---|---|---|
| Reference Name | Electronics Budget | Fashion Budget | Grocery Budget | Endless Survival |
| Leaderboard ID | `leaderboard_electronics_budget` | `leaderboard_fashion_budget` | `leaderboard_grocery_budget` | `leaderboard_endless_survival` |
| Score Format Type | Fixed Point | Fixed Point | Fixed Point | Integer |
| Decimal Places | 2 | 2 | 2 | — |
| Score Order | High to Low | High to Low | High to Low | High to Low |
| Unit (Endless) | — | — | — | Seconds (or leave blank / “sec”) |

**Localization display names:**

| Leaderboard ID | Display Name |
|---|---|
| `leaderboard_electronics_budget` | Electronics Megamart |
| `leaderboard_fashion_budget` | Fashion Boutique |
| `leaderboard_grocery_budget` | Grocery Warehouse |
| `leaderboard_endless_survival` | Midnight Mall |

> Campaign boards: Fixed Point with 2 decimals so raw score (budget × 100) shows as dollars — e.g. 5045 → $50.45.
> Endless board: integer seconds survived.

Art: `Art/Leaderboards/leaderboard_*_budget.png` plus `leaderboard_endless_survival.png`.

---

## Achievements

Create **7 achievements**:

| Reference Name | Achievement ID | Points | Hidden |
|---|---|---|---|
| First Escape | `achievement_first_escape` | 10 | No |
| Mall Master | `achievement_mall_master` | 50 | No |
| Big Saver | `achievement_big_saver` | 25 | No |
| High Roller | `achievement_high_roller` | 25 | No |
| Veteran Shopper | `achievement_veteran` | 50 | No |
| Coupon King | `achievement_coupon_king` | 25 | No |
| Night Owl | `achievement_night_owl` | 25 | No |

**Localization descriptions:**

| Achievement ID | Title | Description |
|---|---|---|
| `achievement_first_escape` | First Escape | Survive your first store run. |
| `achievement_mall_master` | Mall Master | Clear all three stores in the mall. |
| `achievement_big_saver` | Big Saver | Win a run with $80 or more budget remaining. |
| `achievement_high_roller` | High Roller | Reach player level 8 in a single run. |
| `achievement_veteran` | Veteran Shopper | Win 5 total runs. (shows progress in Game Center) |
| `achievement_coupon_king` | Coupon King | Deploy 10 LURE coupons in a single run. |
| `achievement_night_owl` | Night Owl | Survive for 2 minutes in Midnight Mall. |

Art: `Art/Achievements/achievement_*.png` (add `achievement_coupon_king.png` and `achievement_night_owl.png`).

---

## Xcode Capability

In Xcode → target → **Signing & Capabilities** → **+ Capability** → add **Game Center**.

---

## Score Logic (code reference)

- Campaign score submitted = `Int(budget * 100)` (cents precision) on win
- Endless score submitted = `Int(seconds)` on run end
- Achievements evaluated in `GameCenterManager`
- Total wins tracked in `UserDefaults` under key `gcTotalWins`
- Local bests always save even when Game Center is unavailable

---

## Controller Mapping (Game Controllers capability — optional)

| Physical Input | Game Action |
|---|---|
| Left thumbstick | Move player |
| A / Cross | Deploy coupon lure ahead of player |
| Menu / Options | Toggle pause |

Controller IDs defined in `GameControllerManager.swift`.
Game Center IDs defined in `GameCenterManager.swift` (`GameCenterID` enum).
