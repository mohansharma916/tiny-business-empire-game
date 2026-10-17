extends GutTest

# Smoke test: the simulator drives the real EconomyService. Pacing targets
# themselves are checked by running tools/sim/run_sim.gd, not here, so
# retuning config/ never breaks the unit tests.

const SETTINGS := {
	"duration_seconds": 600,
	"decision_interval_seconds": 1.0,
	"player": {"retap_delay_seconds": 0.5, "active_fraction": 1.0, "attention_period_seconds": 10},
}


func test_sim_plays_the_fixture_economy() -> void:
	var sim := PacingSim.new(EconomyFixture.config(), SETTINGS).run()
	# First tap after the 0.5 s reaction delay, then a 2 s cycle.
	assert_almost_eq(sim.milestones["first_sale"], 2.5, 0.01)
	assert_true(sim.milestones.has("first_upgrade"))
	assert_true(sim.milestones.has("first_manager"))
	assert_true(sim.milestones.has("business_2"), "the fixture cart (1,000) is reachable in 10 min")
	assert_gt(sim.purchases.size(), 5)
	assert_lt(sim.worst_wait, 300.0)
