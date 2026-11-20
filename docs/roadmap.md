# Five Minutes — Roadmap

Hobby pace, ~6–8 hrs/week. **Rule:** no new feature until the current milestone is done and playable.

Tick boxes as criteria land. When a milestone merges, collapse it into the Done table with its merge commit.

**Current: M8 — Surged dealer**

---

## Pass 2 (planned 2026-11-20, ~4–5 months)

The pitch is "beat people on Surge by taking it yourself", but no enemy is on Surge yet and banked Samples buy nothing. Pass 2 fixes both, then ships, then deepens.

### M8 — Surged dealer · 3 wks

Second enemy type. Makes dosing necessary, not optional.

- [ ] Dealer enemy patrols/fights like the cop but doses mid-fight
- [ ] Dosed dealer gets a power with a clear visual + audio tell
- [ ] Sober pistol barely hurts a dosed dealer
- [ ] Playtest: the fight can't reasonably be won without dosing

### M9 — Real powers · 3–4 wks

- [ ] 4 final powers replace the placeholders in `scripts/powers/powers.gd`
- [ ] Each power has a visual + audio tell
- [ ] Each tuned against both cop and dealer
- [ ] Still rolled per run as the genome

### M10 — Research hub · 3 wks

- [ ] Between-run hub scene (run ends → hub → next run)
- [ ] Spend banked Samples on unlocks (e.g. see genome early, crash resistance, start with a pill)
- [ ] Meta save is separate from the run save and survives death wipes

### M11 — Ship it · 2–3 wks _(was M7)_

- [ ] Switch to Compatibility renderer; noir look still holds
- [ ] Web export runs in browser
- [ ] Published on itch.io
- [ ] 5 people playtest
- [ ] Top 3 issues fixed

### M12 — Tiers & overload · 2–3 wks

- [ ] Hub research raises power tier
- [ ] Stacking pills raises intensity
- [ ] Past a threshold, overload death risk
- [ ] Crash + overload make "one more pill?" a real gamble

### M13 — First boss · 3–4 wks

- [ ] District kingpin, permanently Surged with several powers
- [ ] Beating him is an alternate extraction worth more Samples

### M14 — Case files · 2 wks

- [ ] Collectible case files in the district
- [ ] Evidence board in the hub shows collected files
- [ ] Light touch, no cutscenes

### Optional

- [ ] Replace X Bot mannequins with real cop / dealer / kingpin models (fold into M13 or own art pass)

---

## Done

| #   | Milestone             | Merged    |
| --- | --------------------- | --------- |
| 1   | Move & shoot          | `3e83ec7` |
| 2   | One enemy, one street | `76f7f8a` |
| 3   | The Dose              | `ce0aaf4` |
| 4   | The Crash             | `3b8f047` |
| 5   | Full run              | `1c51394` |
| 6   | Noir art pass         | `998d394` |

Pass 1 wrapped 2026-11-20; desktop playtest passed. Old M7 (ship) moved to M11.
