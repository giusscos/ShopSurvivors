# App Store Connect Checklist — Version 1.0

Use this when preparing the $2.99 paid release.

---

## Pricing & availability

- [ ] Price tier: **$2.99** (or local equivalent)
- [ ] Optional: short intro sale at $0.99
- [ ] Availability: selected territories
- [ ] No IAP / subscriptions for v1

---

## App information

- [ ] Name: **Shop Survivors**
- [ ] Subtitle: short VS-mall pitch (e.g. “Protect the budget”)
- [ ] Category: Games → Action (secondary: Casual)
- [ ] Age rating: complete questionnaire (cartoon combat, no gore)
- [ ] Privacy nutrition labels: **no data collected** for tracking; Game Center is Apple’s service
- [ ] Export compliance: **ITSAppUsesNonExemptEncryption = NO** (set in Xcode)
- [ ] Privacy Manifest present: `ShopSurvivors/PrivacyInfo.xcprivacy`

---

## Assets

- [ ] App Icon 1024×1024 **RGB, no alpha** (verified in Assets)
- [ ] Screenshots: landscape iPhone + iPad (title, mall hub, in-run HUD, results)
- [ ] Optional preview video

---

## Game Center

Complete `metadata/1.0/game-center-setup.md`:

- [ ] 4 classic leaderboards (3 budget + Endless survival)
- [ ] 7 achievements (including Coupon King + Night Owl)
- [ ] Upload art from `Art/Leaderboards/` and `Art/Achievements/`
- [ ] Capability enabled on the App ID / Xcode target

---

## TestFlight smoke test

- [ ] ProMotion device: timer / movement feel correct (not 2× speed)
- [ ] Multi-level-up from big XP: multiple upgrade picks in a row
- [ ] Background app mid-run → returns paused
- [ ] Game Center signed-out: trophy still visible, prompts sign-in
- [ ] Clear Grocery → Midnight Mall door unlocks
- [ ] Local best shows on hub doors and results
- [ ] Controller: move, A lure, Menu pause
