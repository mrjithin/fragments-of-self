class_name GameEvent
extends RefCounted
## A small random "event of the day" — a flavour beat surfaced on the task board that
## varies per playthrough (RNG-driven). Each can carry a DID fact (the information loop)
## and is gated by the current day. Authored in data/events.json, no code per event.

var id: String = ""
var weight: float = 1.0
var min_day: int = 1
var max_day: int = 9999
var fact: String = ""          # optional DID fact id to surface
var text: String = ""          # the line shown to the player


static func from_dict(d: Dictionary) -> GameEvent:
	var e := GameEvent.new()
	e.id = d.get("id", "")
	e.weight = maxf(0.0, float(d.get("weight", 1.0)))
	e.min_day = int(d.get("min_day", 1))
	e.max_day = int(d.get("max_day", 9999))
	e.fact = d.get("fact", "")
	e.text = d.get("text", "")
	return e


func available_on(day: int) -> bool:
	return day >= min_day and day <= max_day
