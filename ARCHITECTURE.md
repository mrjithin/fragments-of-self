# Architecture (proposed)

This is a forward-looking plan for how the Godot 4.6 project should be organized as systems are built. Nothing here is implemented yet — treat it as the target shape and update it as decisions are made.

## Two views, one shared state

The game runs on two primary views that must stay cleanly decoupled and communicate only through a shared state layer and an event bus:

- **External World view** — the protagonist's life: cutscenes, dialogue, task assignment, mini-games.
- **Internal Mind view** — the alter graph: managing alters, resolving conflicts, stress/rest, internal missions.

```
              ┌─────────────────────────────┐
              │        Autoload layer        │
              │  GameState · EventBus · Clock │
              │  SaveManager · RNG · DIDFacts │
              └───────────────┬──────────────┘
                              │ (signals + shared state)
        ┌─────────────────────┴─────────────────────┐
        ▼                                            ▼
┌─────────────────┐                        ┌─────────────────┐
│ External World  │   ←── events / state ──→ │ Internal Mind   │
│  scene + systems │                        │  scene + systems │
└─────────────────┘                        └─────────────────┘
```

## Autoload singletons (global state)

Register these as autoloads in `project.godot`. Keep them small and signal-driven.

- **GameState** — current chapter/age, day, progression flags, unlocked endings/achievements, active choices.
- **EventBus** — global signals so External and Internal systems never reference each other directly (e.g. `alter_spawned`, `memory_unlocked`, `day_ended`, `relationship_changed`).
- **GameClock** — in-day time budget, day advancement, time jumps.
- **RNG** — single seeded random source for the randomness system (seed stored in save for reproducible playthroughs).
- **SaveManager** — serialize/deserialize GameState and per-system data.
- **DIDFacts** — surfaces context-appropriate awareness content (info loop).

## Suggested folder layout

```
res://
├── project.godot
├── autoload/            # GameState.gd, EventBus.gd, GameClock.gd, RNG.gd, SaveManager.gd, DIDFacts.gd
├── scenes/
│   ├── external/        # external world view, cutscenes, dialogue UI, task board
│   ├── internal/        # mind graph view, alter nodes, conflict/dialogue UI, rejuvenation
│   ├── minigames/       # memory-unlock mini-games
│   └── ui/              # HUD, menus, achievement/relationship panels
├── scripts/
│   ├── systems/         # alter manager, relationship manager, task/assignment, event/randomness
│   └── models/          # Alter, Relationship, Task, Memory, Choice (class_name resources)
├── data/                # JSON + .tres content (see below)
├── assets/
│   ├── art/             # pixel art (gameplay) + vector art (cutscenes)
│   ├── audio/           # music, ambience, sfx
│   └── voice/           # per-alter voice lines
└── docs/                # design notes beyond the root .md files
```

## Data-driven content

Story, dialogue, alters, events, and DID facts should be authored as data, not code, so content can be added without programming. Use **JSON** for story/dialogue (per the design doc) and Godot **`Resource` (.tres)** for typed game objects where editor integration helps.

Core data models to define (`class_name` resources):

- **Alter** — id, name, role, personality, skills/strengths, stress level, triggers, coping mechanisms, memory access, voice id.
- **Relationship** — pair of alters (or alter↔NPC), affinity, status (broken/strained/healthy), modifiers applied to external-world function.
- **Task** — type (dialogue / mini-game / timed), required skills, time cost, outcomes, story effects.
- **Memory** — fragment id, unlock conditions (triggers, goals, mini-game completion), narrative payload, mystery linkage.
- **StoryNode / DialogueNode** — JSON-backed branching dialogue with choices and consequences.
- **GameEvent** — random/scripted external-world event, weighted by RNG and current state.

## Systems to build (maps to design doc)

| System | Responsibility | View |
|---|---|---|
| Randomness | Weighted random external events, randomized alter count/stats | shared |
| External World | Cutscenes, dialogue interactions, task board & assignment UI | external |
| Alter Manager | Spawn/track alters, stats, stress, rest/rejuvenation | internal |
| Relationship Manager | Alter↔alter and alter↔NPC relationships, mending via dialogue | internal + external |
| Task/Assignment | Assign alters to tasks (skill match, co-working main+voices) | external |
| Mystery/Memory | Unlock conditions, fragment reveal, mystery progression | shared |
| Information | Surface DID facts contextually | shared |
| Progression | Age/time advancement, day budget, endings & achievements | shared |
| HUD | Progress, relationships, achievements display | ui |
| Save/Load | Persist full game state incl. RNG seed | shared |

## Build order (toward first-playable in < 6 months)

1. Autoload skeleton (GameState, EventBus, GameClock, RNG, SaveManager).
2. Data models + a tiny sample content set in `data/`.
3. Internal Mind view: render alter graph from data, basic stats/stress display.
4. External World view: dialogue system reading JSON, simple task board.
5. Assignment loop tying alters → tasks, with relationship effects.
6. One mini-game + one memory unlock to prove the mystery loop.
7. Day cycle + HUD + save/load → vertical slice / first-playable.
