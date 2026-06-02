extends Node
## Thin in-day time budget. No real-time ticking — time is spent in discrete chunks
## when the player takes actions (resolving a conflict, resting an alter, etc.).

const DEFAULT_BUDGET: int = 100

var budget_total: int = DEFAULT_BUDGET
var budget_remaining: int = DEFAULT_BUDGET


func reset_day(total: int = DEFAULT_BUDGET) -> void:
	budget_total = total
	budget_remaining = total
	EventBus.time_spent.emit(0, budget_remaining)


## Restore a saved time budget (used by SaveManager on Continue) and refresh the HUD.
func load_state(total: int, remaining: int) -> void:
	budget_total = maxi(1, total)
	budget_remaining = clampi(remaining, 0, budget_total)
	EventBus.time_spent.emit(0, budget_remaining)


func spend(amount: int) -> void:
	budget_remaining = maxi(0, budget_remaining - amount)
	EventBus.time_spent.emit(amount, budget_remaining)
