# Fragments of Self

A 2D narrative / strategy / management game built in **Godot 4.6**. You inhabit the mind of a protagonist living with **Dissociative Identity Disorder (DID)** — managing their alters, resolving internal conflicts, navigating the demands of the outside world, and reconstructing their past, piece by piece.

> **Why this game exists.** Fragments of Self aims to spread awareness of DID and break stereotypes through an empathetic, authentic portrayal — no sensationalism, no horror tropes, no "split personality villain" clichés. The framing is cozy, safe, and grounded in real-world facts. DID is real, and so is recovery.

## The premise

You are the inner voice with the power to act. The external world is seen through the protagonist's eyes; the internal world is an interconnected graph of alters — each born to carry something, each with their own role, strengths, and triggers. Your choices ripple outward: how you treat the parts shapes how the whole survives the week, and which ending the story earns.

## Gameplay

A complete **5-day arc**. Each day flows through two connected views:

### External World
- A day hub (the task board) offers the day's situations: one fixed main story beat plus randomly drawn life tasks — bills, errands, a knock at the door, a friend in crisis.
- Situations play out as branching dialogue with real choices and consequences.
- A limited daily time budget binds: you can't do every task, rest everyone, *and* mend every bond. Tasks left unattended cost you at day's end.

### Internal Mind
- The system is visualised as a graph of **four alters** — a coordinator, a protector, an achiever, and a caretaker — with their relationships drawn as living connections (healthy, strained, or broken).
- For each task, you choose who fronts. **Talk** to mend strained bonds through dialogue, **Rest** an overwhelmed alter, or **Send** someone to handle the situation.
- Choosing has real stakes: every task has a required skill and a potential trigger. Sending an alter who lacks the skill, gets hit by a trigger, is already overwhelmed, or carries a strained bond costs alignment and spikes stress.
- **Stress is a resource.** Work tires alters, stress persists and compounds across days, and rest only partly relieves it. There is no hard wall — you *may* send anyone — but you pay for a poor choice.

### Coping is a gamble
Outcomes are a real, seeded roll: a good alter-to-task fit raises the odds but never guarantees success, and a poor fit can still scrape by. Runs are reproducible (seeded RNG), and consequences — alignment shifts, stress spikes, breaking points — are surfaced to the player, not hidden.

### Mystery loop
Completing situations unlocks fragments of the protagonist's past. Each recovered memory is reassembled by hand in a tile-puzzle mini-game, and the pieces slowly answer the question the game opens with: *what happened?* Day 5 is a single finale that completes the mystery.

### Information loop
Woven through the story, the game surfaces **real DID facts** in context — gentle, non-blocking notes that build an accurate picture of the condition: what alters are, how switching actually looks, where DID comes from, and what recovery means.

### The Journal
A codex tracks everything you've come to understand: recovered **Memories**, learned **DID Facts**, **The System** (the alters as you've come to know them — triggers stay hidden until you've lived through them), and **Milestones** (run achievements).

### Endings
The run closes with one of **three path-based endings** — *Integration*, *Cooperation*, or *Survival* — decided by how you treated the system across the week. Care (match strengths, avoid triggers, mend bonds, rest wisely) leads toward Integration; neglect leads toward Survival. Five achievements reward different ways of playing. Multiple endings and randomized days keep replays distinct.

## Features

- **Two integrated systems** — External World and Internal Mind, cleanly separated, talking through a shared state layer and an event bus.
- **Strategy with consequences** — choices affect not just the current scene but the whole run, and are reflected in the story.
- **Real randomness, reproducible runs** — a seeded RNG drives weighted, non-repeating daily events and outcome rolls.
- **Data-driven content** — days, tasks, situations, alters, relationships, dialogue, memories, facts, and events all live in JSON (`data/*.json`); new content needs no code changes.
- **Persistent, versioned saves** — continue a run mid-day; a finished run clears its save.
- **Cozy, warm presentation** — autumn-toned pixel-art scenes, a scene-reactive ambient soundtrack with gentle crossfades, and procedurally generated art and audio.
- **Sensitive by design** — a content/framing note up front, empathetic tone throughout, and an awareness note to close.

## Running the game

1. Install [Godot 4.6](https://godotengine.org/).
2. Open the project folder in the editor and press Play, or run from the command line:

```sh
godot --path .
```

The game starts at the title screen (`scenes/ui/title_screen.tscn`). `Esc` opens the pause menu (with a working sound toggle).

## For developers

- **[ARCHITECTURE.md](ARCHITECTURE.md)** — code/scene structure: autoloads, systems, models, and the view-handoff flow.
- **[GAME_DESIGN.md](GAME_DESIGN.md)** — the full design document.
- **[CLAUDE.md](CLAUDE.md)** — working conventions for the repository.
- **[CREDITS.md](CREDITS.md)** — third-party assets and licenses.

Headless dev tools live in `tools/`: full-playthrough and per-system simulations, scene validation, and the procedural art/audio generators. For example:

```sh
godot --headless --path . res://tools/sim_playthrough.tscn
```

An automated test suite (500+ checks across state, models, relationships, coping odds, persistence, dialogue effects, and content integrity) runs headless too:

```sh
godot --headless --path . res://tools/tests/test_runner.tscn
```

## A note on the subject matter

This game portrays DID authentically and respectfully, grounded in real-world information. It touches on trauma and difficult memories. If you or someone you know is struggling, please reach out to a mental-health professional — people with DID can and do live full, meaningful lives.
