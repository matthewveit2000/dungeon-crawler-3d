class_name CombatActor
extends CharacterBody3D
## Shared modular base class for all non-player living combat actors (enemies, floor bosses,
## and future player summons & wacky companions) (D-051, D-055).
## Owns universal identity, faction, unified EntityStats, StatusComponent, knockback physics,
## and pluggable ActorLocomotion + ActorBrain components.

enum AiState { DORMANT, IDLE, CHASE, ATTACK, FLEE_SAFE_ZONE, DEAD }

const FACTION_ENEMY := "enemy"
const FACTION_ALLY := "ally"
const FACTION_PLAYER := "player"
const FACTION_NEUTRAL := "neutral"

var faction: String = FACTION_ENEMY
var display_name: String = "Actor"
var level: int = 1
var body_radius: float = 0.5
var state: AiState = AiState.IDLE

var entity_stats: EntityStats = EntityStats.new()
var status_comp: StatusComponent = StatusComponent.new()
var locomotion: ActorLocomotion = ActorLocomotion.new()
var brain: ActorBrain = ActorBrain.new()

var max_health: float = 60.0
var current_health: float = 60.0
var damage: float = 12.0
var armor: float = 6.0
var move_speed: float = 3.8

## Shared status dictionary alias backed directly by status_comp.entries (backwards compatible).
var statuses: Dictionary:
	get:
		return status_comp.entries
	set(v):
		status_comp.entries = v

var _stun_t: float:
	get:
		return status_comp.stun_t
	set(v):
		status_comp.stun_t = v

var _unseen_t: float:
	get:
		return brain.unseen_t
	set(v):
		brain.unseen_t = v

var _knock_vel: Vector3 = Vector3.ZERO
var _since_hurt: float = 99.0


func is_alive() -> bool:
	return state != AiState.DEAD and current_health > 0.0


## True when this actor should treat `other_faction` as hostile.
func is_hostile_to(other_faction: String) -> bool:
	if faction == FACTION_NEUTRAL or other_faction == FACTION_NEUTRAL:
		return false
	if faction == FACTION_ENEMY:
		return other_faction == FACTION_PLAYER or other_faction == FACTION_ALLY
	if faction == FACTION_ALLY or faction == FACTION_PLAYER:
		return other_faction == FACTION_ENEMY
	return false


func has_status(kind: String) -> bool:
	return status_comp.has(kind)


func effective_armor() -> float:
	return maxf(0.0, armor - status_comp.armor_reduction())


func is_incapacitated() -> bool:
	return status_comp.is_incapacitated()


func is_invulnerable() -> bool:
	return status_comp.is_invulnerable()
