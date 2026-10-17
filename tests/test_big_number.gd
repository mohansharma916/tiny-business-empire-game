extends GutTest

const EPSILON: float = 1e-9


func _bn(value: float) -> BigNumber:
	return BigNumber.from_float(value)


# --- Construction -----------------------------------------------------------

func test_normalizes_mantissa_into_one_to_ten() -> void:
	var n := _bn(12345.0)
	assert_almost_eq(n.mantissa, 1.2345, EPSILON)
	assert_eq(n.exponent, 4)


func test_normalizes_exact_powers_of_ten() -> void:
	for e in [1, 3, 6, 9, 15]:
		var n := _bn(pow(10.0, e))
		assert_almost_eq(n.mantissa, 1.0, EPSILON, "10^%d mantissa" % e)
		assert_eq(n.exponent, e, "10^%d exponent" % e)


func test_zero_has_zero_exponent() -> void:
	var n := _bn(0.0)
	assert_true(n.is_zero())
	assert_eq(n.exponent, 0)


func test_from_log10_beyond_float_range() -> void:
	var n := BigNumber.from_log10(400.5)
	assert_eq(n.exponent, 400)
	assert_almost_eq(n.mantissa, pow(10.0, 0.5), 1e-6)
	assert_almost_eq(n.log10(), 400.5, 1e-9)


func test_dict_round_trip() -> void:
	var n := BigNumber.new(4.56, 120)
	assert_true(BigNumber.from_dict(n.to_dict()).is_equal(n))


# --- Arithmetic -------------------------------------------------------------

func test_add() -> void:
	assert_almost_eq(_bn(150.0).add(_bn(50.0)).to_float(), 200.0, EPSILON)
	assert_almost_eq(_bn(999.0).add(_bn(1.0)).to_float(), 1000.0, EPSILON)


func test_add_across_large_exponent_gap_keeps_larger() -> void:
	var big := BigNumber.new(1.0, 100)
	assert_true(big.add(_bn(5.0)).is_equal(big))
	assert_true(_bn(5.0).add(big).is_equal(big))


func test_add_beyond_float_range() -> void:
	var a := BigNumber.new(6.0, 400)
	var sum := a.add(BigNumber.new(5.0, 400))
	assert_almost_eq(sum.mantissa, 1.1, EPSILON)
	assert_eq(sum.exponent, 401)


func test_subtract() -> void:
	assert_almost_eq(_bn(200.0).subtract(_bn(50.0)).to_float(), 150.0, EPSILON)
	assert_true(_bn(42.0).subtract(_bn(42.0)).is_zero())
	assert_true(_bn(10.0).subtract(_bn(20.0)).is_negative())


func test_multiply() -> void:
	assert_almost_eq(_bn(25.0).multiply(_bn(4.0)).to_float(), 100.0, EPSILON)
	var product := BigNumber.new(5.0, 200).multiply(BigNumber.new(4.0, 200))
	assert_almost_eq(product.mantissa, 2.0, EPSILON)
	assert_eq(product.exponent, 401)


func test_multiply_scalar_and_divide() -> void:
	assert_almost_eq(_bn(3.0).multiply_scalar(0.5).to_float(), 1.5, EPSILON)
	assert_almost_eq(_bn(10.0).divide(_bn(4.0)).to_float(), 2.5, EPSILON)
	assert_true(_bn(10.0).divide(BigNumber.zero()).is_zero())


func test_operations_do_not_mutate_operands() -> void:
	var a := _bn(10.0)
	var b := _bn(5.0)
	a.add(b)
	a.subtract(b)
	a.multiply(b)
	assert_almost_eq(a.to_float(), 10.0, EPSILON)
	assert_almost_eq(b.to_float(), 5.0, EPSILON)


# --- Comparison -------------------------------------------------------------

func test_compare() -> void:
	assert_eq(_bn(10.0).compare(_bn(5.0)), 1)
	assert_eq(_bn(5.0).compare(_bn(10.0)), -1)
	assert_eq(_bn(7.0).compare(_bn(7.0)), 0)
	assert_eq(BigNumber.new(1.0, 300).compare(BigNumber.new(9.0, 299)), 1)


func test_compare_signs_and_zero() -> void:
	assert_eq(_bn(-1.0).compare(BigNumber.zero()), -1)
	assert_eq(BigNumber.zero().compare(_bn(0.001)), -1)
	assert_eq(_bn(-100.0).compare(_bn(-1.0)), -1)
	assert_eq(BigNumber.zero().compare(BigNumber.zero()), 0)


func test_comparison_helpers() -> void:
	assert_true(_bn(10.0).is_greater_equal(_bn(10.0)))
	assert_true(_bn(10.0).is_greater_than(_bn(9.0)))
	assert_true(_bn(9.0).is_less_than(_bn(10.0)))


# --- Short format -----------------------------------------------------------

func test_format_short_small_values() -> void:
	assert_eq(_bn(0.0).to_formatted(), "0")
	assert_eq(_bn(0.5).to_formatted(), "0.5")
	assert_eq(_bn(7.0).to_formatted(), "7")
	assert_eq(_bn(999.0).to_formatted(), "999")
	assert_eq(_bn(1234.0).to_formatted(), "1,234")
	assert_eq(_bn(9999.9).to_formatted(), "9,999")


func test_format_short_suffixes() -> void:
	assert_eq(_bn(12345.0).to_formatted(), "12.3K")
	assert_eq(_bn(123456.0).to_formatted(), "123K")
	assert_eq(_bn(4.56e6).to_formatted(), "4.56M")
	assert_eq(_bn(7.89e9).to_formatted(), "7.89B")
	assert_eq(_bn(1e12).to_formatted(), "1.00T")


func test_format_short_letter_suffixes() -> void:
	assert_eq(BigNumber.new(1.0, 15).to_formatted(), "1.00aa")
	assert_eq(BigNumber.new(2.5, 19).to_formatted(), "25.0ab")
	assert_eq(BigNumber.new(1.0, 15 + 3 * 25).to_formatted(), "1.00az")
	assert_eq(BigNumber.new(1.0, 15 + 3 * 26).to_formatted(), "1.00ba")


func test_format_never_rounds_up() -> void:
	assert_eq(_bn(999999.0).to_formatted(), "999K")
	assert_eq(_bn(4.569e6).to_formatted(), "4.56M")


func test_format_beyond_letters_falls_back_to_scientific() -> void:
	assert_eq(BigNumber.new(3.21, 3000).to_formatted(), "3.21e3000")


func test_format_negative() -> void:
	assert_eq(_bn(-12345.0).to_formatted(), "-12.3K")


# --- Indian format ----------------------------------------------------------

func test_format_indian_below_lakh() -> void:
	assert_eq(_bn(999.0).to_formatted(true), "999")
	assert_eq(_bn(1234.0).to_formatted(true), "1,234")
	assert_eq(_bn(99999.0).to_formatted(true), "99,999")


func test_format_indian_lakh_and_crore() -> void:
	assert_eq(_bn(123456.0).to_formatted(true), "1.23L")
	assert_eq(_bn(4.5e6).to_formatted(true), "45.0L")
	assert_eq(_bn(1.0e7).to_formatted(true), "1.00Cr")
	assert_eq(_bn(4.56e8).to_formatted(true), "45.6Cr")
	assert_eq(_bn(1.5e9).to_formatted(true), "150Cr")


func test_format_indian_grouped_crores() -> void:
	assert_eq(_bn(1.2345e10).to_formatted(true), "1,234Cr")
	assert_eq(_bn(9.9999e11).to_formatted(true), "99,999Cr")


func test_format_indian_falls_back_to_short_scale() -> void:
	assert_eq(_bn(1e12).to_formatted(true), "1.00T")


func test_format_tolerates_float_error_below_a_whole_number() -> void:
	assert_eq(BigNumber.from_log10(2.0).to_formatted(), "100")
	assert_eq(_bn(99.99999999999).to_formatted(), "100")
