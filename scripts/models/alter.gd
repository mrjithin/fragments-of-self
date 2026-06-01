class_name Alter
extends RefCounted
## A part of the protagonist — a personality holding a role, skills, and stress.

const STRESS_HIGH: int = 65   # at or above this, the alter visibly needs rest

var id: String = ""
var name: String = ""
var role: String = ""
var skills: Array[String] = []
var stress: int = 0
var triggers: Array[String] = []
var color: Color = Color.WHITE
var graph_pos: Vector2 = Vector2.ZERO


static func from_dict(d: Dictionary) -> Alter:
	var a := Alter.new()
	a.id = d.get("id", "")
	a.name = d.get("name", "")
	a.role = d.get("role", "")
	a.stress = int(d.get("stress", 0))
	a.color = Color(d.get("color", "#ffffff"))
	for s in d.get("skills", []):
		a.skills.append(str(s))
	for t in d.get("triggers", []):
		a.triggers.append(str(t))
	var pos: Dictionary = d.get("graph_pos", {})
	a.graph_pos = Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)))
	return a


func has_skill(skill: String) -> bool:
	return skills.has(skill)


func is_stressed() -> bool:
	return stress >= STRESS_HIGH
