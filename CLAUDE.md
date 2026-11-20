# Five Minutes — One-Page Design Doc

**Pitch:** A former cop turned vigilante hunts the dealers flooding his city with Surge, a pill that gives a random superpower for a few minutes. The catch: the only way to beat people on Surge is to take it yourself.

**Genre:** Third-person shooter roguelite · **Platform:** Browser (Godot 4 web export) · **Team:** Solo hobbyist · **Tone:** Gritty street drama

**Art style: Low-poly noir, not blocky.** Clean, mid-poly models with smooth shading and bevelled edges (no voxels, no cubes). Lighting carries the mood: night, rain, fog, wet streets, orange sodium streetlights, desaturated grade. **When you dose, the colour floods back in.**

---

## Core loop (one run, 10–15 min)

1. **Enter the district** powerless with a pistol.
2. **Fight and scavenge** — find pills and Samples.
3. **Dose** when you choose → short power window.
4. **Crash** when it ends — you're weak and hunted.
5. **Extract** to bank Samples, or **die** and lose the run.

## The 3 mechanics

1. **The Dose** — A pill gives a ~75-second power window. Your power is random each run (your "genome") and revealed on the first pill. The screen snaps from grey to full colour. _Powers are open for rework; build with 2–3 placeholders._
2. **The Crash** — When the dose ends: weapon sway, slower aim, blurred vision, less health. More pills per run = worse crash. This is the risk that makes choosing _when_ to dose matter.
3. **Extract or Lose It** — Samples collected during a run only count if you reach the extraction point. Death wipes the run. Save-and-quit is allowed (the save deletes on load).

_Research hub, final powers, power tiers, overload, boss, and story are scheduled in Pass 2 — see the roadmap._

---

## Milestones

**Current: M8 — Surged dealer.** Full plan, checklists, and history live in [`docs/roadmap.md`](docs/roadmap.md). Rule: no new feature until the current milestone is done and playable.
