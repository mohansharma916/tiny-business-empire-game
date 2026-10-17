extends Node

# Autoload "EconomyService": the only economy API the UI may use
# (AGENTS.md section 2). The UI reads state and calls these methods;
# it never computes or stores money itself.
#
# Contract stage: signatures and signals are final, bodies are stubs.

signal cash_changed(cash: BigNumber)
signal income_changed(income_per_second: BigNumber)
signal business_purchased(business_id: String)
signal upgrade_purchased(business_id: String, track: String, new_level: int)
signal business_automated(business_id: String)
signal location_unlocked(location_id: String)
## milestone_id is "<business_id>:<track>:<level>", e.g. "chai_stall:quality:25".
signal milestone_reached(milestone_id: String)

## Pass as `amount` to buy_upgrade() / get_upgrade_cost() for the ×Max button.
const BULK_MAX: int = -1

var config: GameConfig
var lifecycle: AppLifecycle = AppLifecycle.new()

var _cash: BigNumber = BigNumber.zero()
var _income_per_second: BigNumber = BigNumber.zero()


func _ready() -> void:
	config = GameConfig.load_from_dir()


func _notification(what: int) -> void:
	lifecycle.handle_notification(what)


func get_cash() -> BigNumber:
	return _cash


## Sum of every business that earns without tapping (automated), boosts included.
func get_income_per_second() -> BigNumber:
	return _income_per_second


## Snapshot copy; changing it does nothing. Keys:
## id, owned, levels {track: int}, workers, has_manager, automated,
## cycle_running, cycle_progress (0..1), cycle_seconds, boost_seconds_left,
## income_per_second (BigNumber). Empty if the id is unknown.
func get_business_state(business_id: String) -> Dictionary:
	return {}


func can_afford(cost: BigNumber) -> bool:
	return _cash.is_greater_equal(cost)


## Returns true if the business was bought (emits business_purchased).
func buy_business(business_id: String) -> bool:
	return false


## amount: 1, 10 or BULK_MAX. Returns how many levels were bought (0 = none).
## Buys as many as affordable up to `amount`; emits upgrade_purchased once.
func buy_upgrade(business_id: String, track: String, amount: int = 1) -> int:
	return 0


## Total cost of the next `amount` levels (BULK_MAX: as many as affordable now).
func get_upgrade_cost(business_id: String, track: String, amount: int = 1) -> BigNumber:
	return BigNumber.zero()


## role: "worker" or "manager". Returns true if hired.
func hire_staff(business_id: String, role: String) -> bool:
	return false


## Manual business: starts a serving cycle if none is running.
## Automated business: starts or refreshes the temporary speed boost.
## Returns true if the tap did something. Hold-to-repeat = call it every tick.
func tap_business(business_id: String) -> bool:
	return false
