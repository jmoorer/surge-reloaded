class_name Powers
extends RefCounted
## Placeholder Surge powers. One is rolled per run (the player's "genome") and revealed by
## the first pill. Powers are data + modifiers; Dose applies them through PlayerModifiers.

const ADRENAL := &"adrenal"
const IRONSKIN := &"ironskin"
const DEADEYE := &"deadeye"
const ALL: Array[StringName] = [ADRENAL, IRONSKIN, DEADEYE]

const INFO := {
	ADRENAL: {
		"name": "ADRENAL",
		"desc": "Move faster. Wounds close on their own.",
		"color": Color(0.35, 1.0, 0.45),
	},
	IRONSKIN: {
		"name": "IRONSKIN",
		"desc": "Bullets barely break the skin.",
		"color": Color(0.45, 0.75, 1.0),
	},
	DEADEYE: {
		"name": "DEADEYE",
		"desc": "Every shot hits harder and comes faster.",
		"color": Color(1.0, 0.4, 0.3),
	},
}


static func display_name(id: StringName) -> String:
	return INFO[id]["name"] if INFO.has(id) else "???"


static func color(id: StringName) -> Color:
	return INFO[id]["color"] if INFO.has(id) else Color.WHITE


## Writes this power's effect into the modifier set.
static func modify(id: StringName, m: PlayerModifiers) -> void:
	match id:
		ADRENAL:
			m.speed *= 1.6
			m.regen_per_second += 6.0
		IRONSKIN:
			m.damage_taken *= 0.35
		DEADEYE:
			m.weapon_damage *= 2.0
			m.fire_rate *= 1.6
			m.reload_speed *= 1.5
