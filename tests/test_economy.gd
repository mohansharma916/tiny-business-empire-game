extends GutTest

func test_big_number_addition():
	var a := BigNumber.from_float(150.0)
	var b := BigNumber.from_float(50.0)
	var c := a.add(b)
	assert_almost_eq(c.to_float(), 200.0, 0.01)

func test_big_number_formatting():
	var k := BigNumber.from_float(1250.0)
	assert_eq(k.to_formatted(false), "1.25 K")
	var m := BigNumber.from_float(2500000.0)
	assert_eq(m.to_formatted(false), "2.50 M")

func test_economy_service_state():
	assert_not_null(EconomyService)
	var chai := EconomyService.get_business_state("chai_stall")
	assert_false(chai.is_empty())
	assert_true(EconomyService.can_afford(BigNumber.from_float(10.0)))
