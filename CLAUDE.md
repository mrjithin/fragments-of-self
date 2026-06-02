# CLAUDE.md

Guidance for working in this repository.

## Project

**Fragments of Self** — a 2D narrative/strategy/management game built in **Godot 4.6**. The player inhabits the mind of a protagonist living with **Dissociative Identity Disorder (DID)**, managing their alters, resolving internal conflicts, navigating the external world, and reconstructing the protagonist's past piece by piece. The game's purpose is to spread awareness of DID and break stereotypes through an empathetic, authentic portrayal.

See [GAME_DESIGN.md](GAME_DESIGN.md) for the full design document and [ARCHITECTURE.md](ARCHITECTURE.md) for the intended code/scene structure.

> Sensitive subject matter. DID is portrayed authentically and respectfully, grounded in real-world facts. Avoid sensationalism, horror tropes, or "split personality villain" clichés. When in doubt about tone, prefer the cozy, safe, empathetic framing described in the design doc.

## Current state

Playable vertical slice, now a **4-day arc**. Engine: Godot 4.6, GL Compatibility renderer, Jolt physics (3D engine on by default; game itself is 2D). What exists:

- **Loop:** Title → task board (day hub) → external world (JSON dialogue) → internal mind (alter graph: select/Talk/Rest/Send, conflict dialogue, stress gate) → memory-assembly mini-game → day-end summary (alignment meter, Survival/Cooperation/Integration paths) → next day. Multi-day, relationship-driven outcomes.
- **Autoloads:** `GameState` (single source of truth + serialization), `EventBus` (all cross-view comms), `GameClock`, `RNG` (seeded, `weighted_pick`), `SaveManager` (versioned JSON save incl. clock + RNG seed), `DIDFacts`, `Music` (scene-reactive ambient crossfade), `SceneFlow` (fade transitions), `PauseMenu` (Esc overlay, working Sound toggle).
- **Systems:** alter manager, relationship manager, dialogue runner, JSON loader, `EventPool` (randomness first cut — weighted, non-repeating "event of the day" surfacing a DID fact).
- **Content (data-driven, no code per item):** `data/*.json` — days, tasks, situations (day1–4), alters, relationships, conflict dialogue, memories, DID facts, random events.
- **Audio:** per-view ambient pads, generated procedurally (`tools/gen_audio.gd`), crossfade on `EventBus.scene_changed`.
- **Dev tools (`tools/`):** headless sims (`sim_playthrough`, `sim_continue`, `sim_day3`, `sim_day4`, `sim_events`, `sim_audio`), `validate_scenes.gd`, asset generators (`gen_pixel_art`, `gen_audio`). Run e.g. `godot --headless --path . res://tools/sim_playthrough.tscn`. After adding a new `class_name`, run `godot --headless --editor --quit` once to refresh the global class cache.

See [ARCHITECTURE.md](ARCHITECTURE.md) "Status" section for what's built beyond the original build order.

## Tech & conventions

- **Engine:** Godot 4.6. Scripts in **GDScript** unless a specific need argues for C#/GDExtension (decide explicitly, don't mix casually).
- **Language:** Use static typing in GDScript (`var x: int`, typed function signatures) for clarity and editor support.
- **Naming:** `snake_case` for files, variables, and functions; `PascalCase` for nodes, classes (`class_name`), and scene root names. Constants in `UPPER_SNAKE_CASE`.
- **Scenes vs scripts:** One responsibility per scene. Prefer composition (small reusable scenes) over deep inheritance.
- **Signals over polling:** Use Godot signals for decoupled communication; use autoload singletons for global state (game clock, save data, event bus).
- **Data-driven content:** Story, dialogue, alters, events, and DID facts live in **JSON** (and/or Godot `Resource` files), not hardcoded in scripts. See ARCHITECTURE.md.
- **EditorConfig:** Respect `.editorconfig` (tabs for `.gd` per Godot convention).

## Running & testing

- Open the project in the Godot 4.6 editor, or run headless: `godot --path . ` (and `godot --headless` for CI-style runs).
- There is no automated test setup yet. If adding tests, prefer [GUT](https://github.com/bitwes/Gut) and document the run command here.
- Commit `.godot/` is ignored (see `.gitignore`); never commit generated import caches beyond what git already tracks.

## Working agreements

- Keep the two core views — **External World** and **Internal Mind** — cleanly separated as distinct scenes/systems that communicate through a shared state layer and event bus.
- New gameplay content (alters, events, dialogue) should be addable via data files without code changes wherever feasible.
- When implementing a system listed in ARCHITECTURE.md, update that file if the design changes.
- Only commit or push when the user asks.
