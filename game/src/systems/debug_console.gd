class_name DebugConsole
extends RefCounted
## Tier 2 Pure System: Built-in Playtest & Audit Console Command Parser.
## Allows instant verification of any feature (teleport, advance_days, collapse, spawn_loot, god, seed).

const HELP_TEXT := """Available Playtest / Audit Commands:
  help                        Show this list
  teleport <entrance|safe|boss|vault|stairs>   Teleport directly to landmark
  advance_days <float>        Fast-forward the 5-day floor clock (e.g. advance_days 4.9)
  collapse                    Trigger immediate floor collapse reset
  kill_player                 Trigger combat-death floor-entry snapshot reset
  kill_boss                   Defeat the Floor Boss immediately (unlocks Treasure Vault)
  spawn_loot [rarity]         Grant rolled gear (common/uncommon/rare/epic/sponsored)
  add_gold <amount>           Add gold to inventory
  add_xp <amount>             Grant character XP
  god                         Toggle invulnerability
  camera                      Toggle 1st-person / 3rd-person camera
  seed [int]                  Show current seed or regenerate floor with new seed
  status                      Print floor, timer, HP/MP/SP, and position summary"""


static func execute(command_line: String, handlers: Dictionary) -> String:
	var trimmed := command_line.strip_edges()
	if trimmed.is_empty():
		return ""
	var parts := trimmed.split(" ", false)
	var cmd := parts[0].to_lower()
	var args: Array[String] = []
	for i in range(1, parts.size()):
		args.append(parts[i])

	if cmd == "help":
		return HELP_TEXT

	if not handlers.has(cmd):
		return "Unknown command '%s'. Type 'help' for available commands." % cmd

	var fn: Callable = handlers[cmd]
	return str(fn.call(args))
