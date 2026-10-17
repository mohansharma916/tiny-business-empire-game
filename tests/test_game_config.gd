extends GutTest


func test_loads_every_config_file() -> void:
	var config := GameConfig.load_from_dir()
	assert_false(config.economy.is_empty(), "economy.json")
	assert_false(config.get_business("chai_stall").is_empty(), "businesses.json")
	assert_eq(config.get_track_names().size(), 4, "upgrades.json tracks")
	assert_false(config.get_staff("worker").is_empty(), "upgrades.json staff")
	assert_eq(config.synergies.size(), 2, "synergies.json")
	assert_eq(config.locations.size(), 2, "locations.json")


func test_autoload_is_registered() -> void:
	assert_not_null(EconomyService)
	assert_not_null(EconomyService.config)
	assert_not_null(EconomyService.get_cash())
