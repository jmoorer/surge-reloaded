class_name PlayerModifiers
extends RefCounted
## Every stat multiplier the dose/crash can touch, recomputed from scratch on each change so
## effects never stack up or leak after they end. Neutral values = no effect.

var speed := 1.0
var regen_per_second := 0.0
var damage_taken := 1.0
var weapon_damage := 1.0
var fire_rate := 1.0
var reload_speed := 1.0
## Fraction of max health that is locked away (0 = none).
var max_health_penalty := 0.0
var look_sensitivity := 1.0
## Camera sway amplitude in degrees (crash).
var sway_deg := 0.0
## 0..1 screen blur / double vision strength (crash).
var blur := 0.0
