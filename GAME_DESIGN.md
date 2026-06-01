# Fragments of Self — Game Design Document

## Concept

Help the protagonist, who has **Dissociative Identity Disorder (DID)**, navigate their world by managing their alters, resolving conflicts between alters, and reconstructing their past piece by piece.

**Genres:** Narrative, Strategy, Psychological, Mystery, Simulation, Management.

## Target audience & motivation

**Motivation:** Spread awareness about DID and break stereotypes.

**Audience:** Teenagers, educators, and players of story-driven psychological games such as *Celeste* and *Spiritfarer*.

## Unique selling points

- Blends storytelling with strategy — choices affect both the current state and the overall game, reflected in the story.
- Authentically portrays DID, building an empathetic connection to the protagonist.
- Integrates two systems (external and internal) into engaging gameplay.
- Mystery overtone — players dig into the protagonist's past.
- Educates the player about DID with real-world data and facts to help destigmatise the condition.
- Multiple endings for replayability.
- Each playthrough differs through randomness and choices.

## Player experience & POV

- The player resides in the protagonist's mind and manages all DID-related affairs — acting like an inner voice with the power to enact real changes.
- The player sees the **external world** through the protagonist's eyes, and the **internal world** as an interconnected mind-tree of alters and personalities.

**Intended emotions:** empathy toward the protagonist; understanding of the hardships of life with DID; an unbiased understanding of the condition; the will to help the protagonist live a good life. Mystery-solving and multiple endings sustain engagement.

## Visual & audio style

- **Tone:** Cozy and safe. Bright, warm (autumn-like) palette, with occasional darker tones per scene.
- **Art:** Primarily **pixel art** for gameplay; **vector art** for external-world cutscenes. Reference: *Celeste* (pixel-art gameplay, vector-art dialogue portraits); palette inspired by *Celeste* Chapter 4.
- **Internal system:** An interconnected graph of alters, with edges showing relationships, plus management UI.
- **Sound:** Soothing, no sudden jerks or jarring effects — every note feels like a consequence of the previous. Audio shifts with the scene.
- **Voice:** Cutscenes have voice acting, with distinct voices per alter.

## World fiction

**Beginning:** The player takes control of the protagonist's mind in early childhood (age 5–7), when DID begins. The backstory before this is withheld — a chance to introduce the player to what DID is.

**Journey:** The player progresses through the protagonist's life — overcoming hurdles using specific alters, managing internal affairs, achieving goals, and meeting/building relationships with the people in the protagonist's life. Each alter has a distinct role, voice, skill, and personality.

**End:** The game concludes with the protagonist having lived a happy life; different endings unlock based on tasks done and goals achieved during gameplay.

## Monetization

- One-time purchase. The distinct atmosphere and unique gameplay suit a premium model. No in-game purchases (they would disturb the atmosphere).

## Platforms, tech & scope

- **Platforms:** Primary PC, secondary Mobile; later console port.
- **Tech:** 2D, **Godot**.
- **Timeline:** 1–2 years depending on time/budget. Basic prototype and first-playable in **< 6 months**.
- **Team:** 1 programmer, 1 artist, 1 sound designer; voice artists if resources allow. Art/sound/voice can be freelance.

## Core loops

**External world loop**
- Manage the protagonist's world by assigning specific alters (per their skills) to tasks and juggling the tasks at hand.
- The player is randomly thrown into difficult situations.
- Dialogue/action choices change the story.

**Internal mind loop** (the strategy/puzzle core)
- Manage all alters. New alters appear over time driven by the external loop; by the end there are roughly **10–20** alters (count randomized).
- Resolve conflicts between alters (via dialogue), manage stress levels, and strategically assign alters to background tasks or rest.
- Account for each alter's role, triggers, and coping mechanisms.

**Mystery loop**
- Steadily unlock the protagonist's past memories (via mini-games and completing goals) to understand the story more deeply.

**Information loop**
- Based on the current scene, surface DID awareness content and real-world data.

**Hope:** The player enjoys the experience and leaves with greater awareness of DID.

## Objectives & progression

- The player progresses through time; the protagonist ages as the game advances.
- Gameplay takes place mainly on two screens: the **external world view** and the **internal mind view**.
- **Short-term:** help manage the current situation and overcome its challenges.
- **Long-term:** ensure mental stability and unravel the mystery of the past.

## Game systems

- Internal **randomness system** for random external-world events.
- **External world system** — dialogue interactions, cutscenes, task-management UI.
- **Resource management system** for the internal mind, plus an **NPC relationship-management system**.
- A structured **JSON** system for story and dialogue.
- A **HUD** showing current progress, relationships, and achievements.

## Interactivity & main gameplay

### External world
- Face real-life situations as the protagonist navigates life: relationship-building dialogues, puzzles (mini-games), timed tasks.
- Decide task order and assign specific alters based on personality and skills.
- Spend extra time on alter upskilling to improve stats.
- Allow multiple alters to co-work (one main + others as voices in the head) — depends on internal-world relationships.
- Specific triggers unlock memories that unravel the mystery.

### Internal world
- Strategically manage alters. Alters have stats: strengths, stress levels, triggers, memory access.
- Use these stats to solve specific tasks. New alters appear periodically and must be accommodated.
- All alters have relationships with each other; mend broken relationships through dialogue (the player is the **manager alter**). Relationships directly affect external-world function.
- Use diplomacy and complete internal missions to unlock new missions and suppressed memories.
- Manage stress levels; assign alters to the **rejuvenation** area strategically.
- A day has limited time — accomplish as much as possible and prepare for the next day. Time jumps may occur between.

### Ending
- The game ends when the protagonist's life story is complete.
- Different endings and achievements unlock based on choices and whether the mystery was solved.
