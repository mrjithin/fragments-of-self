extends Node
## Global signal hub. External and Internal views communicate ONLY through these
## signals (and shared state in GameState) — they never reference each other directly.

# --- View handoff (the two-view spine) ---
signal enter_mind_requested(task_id: String)
signal exit_mind_requested(assigned_alter_id: String)

# --- Internal mind ---
signal alter_selected(alter_id: String)
signal conflict_resolved(alter_a: String, alter_b: String, new_affinity: int)
signal alter_sent_to_rejuvenation(alter_id: String)
signal alter_assigned_to_task(alter_id: String, task_id: String)
signal relationship_changed(alter_a: String, alter_b: String, affinity: int)
signal alter_stress_changed(alter_id: String, stress: int)

# --- Mystery / information ---
signal memory_unlocked(memory_id: String)
signal did_fact_surfaced(fact_id: String)

# --- Progression ---
signal time_spent(amount: int, remaining: int)
signal day_ended(summary: Dictionary)

# --- Guidance (drives the HUD objective hint for the guided demo) ---
signal objective_changed(text: String)
