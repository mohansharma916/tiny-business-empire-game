class_name BigNumber
extends RefCounted

var mantissa: float = 0.0
var exponent: int = 0

const SUFFIXES: Array[String] = [
	"", "K", "M", "B", "T", "aa", "ab", "ac", "ad", "ae", "af", "ag", "ah", "ai", "aj",
	"ak", "al", "am", "an", "ao", "ap", "aq", "ar", "as", "at", "au", "av", "aw", "ax", "ay", "az",
	"ba", "bb", "bc", "bd", "be", "bf", "bg", "bh", "bi", "bj", "bk", "bl", "bm", "bn", "bo"
]

func _init(m: float = 0.0, e: int = 0) -> void:
	mantissa = m
	exponent = e
	_normalize()

static func create(m: float, e: int = 0) -> BigNumber:
	var bn := BigNumber.new(m, e)
	return bn

static func from_float(val: float) -> BigNumber:
	return BigNumber.new(val, 0)

static func zero() -> BigNumber:
	return BigNumber.new(0.0, 0)

static func one() -> BigNumber:
	return BigNumber.new(1.0, 0)

func _normalize() -> void:
	if is_zero_approx(mantissa) or mantissa == 0.0:
		mantissa = 0.0
		exponent = 0
		return
	if mantissa < 0.0:
		# Keep negative sign if any, normalize absolute value
		var sign_val: float = -1.0
		mantissa = absf(mantissa)
		_normalize_positive()
		mantissa *= sign_val
	else:
		_normalize_positive()

func _normalize_positive() -> void:
	while mantissa >= 10.0:
		mantissa /= 10.0
		exponent += 1
	while mantissa < 1.0 and mantissa > 0.0:
		mantissa *= 10.0
		exponent -= 1

func duplicate_bn() -> BigNumber:
	return BigNumber.new(mantissa, exponent)

func is_zero() -> bool:
	return mantissa == 0.0

func compare_to(other: BigNumber) -> int:
	if mantissa == 0.0 and other.mantissa == 0.0:
		return 0
	if mantissa < 0.0 and other.mantissa >= 0.0:
		return -1
	if mantissa >= 0.0 and other.mantissa < 0.0:
		return 1
	if exponent != other.exponent:
		if exponent > other.exponent:
			return 1 if mantissa > 0.0 else -1
		else:
			return -1 if mantissa > 0.0 else 1
	var diff: float = mantissa - other.mantissa
	if absf(diff) < 1e-9:
		return 0
	return 1 if diff > 0.0 else -1

func is_greater_than(other: BigNumber) -> bool:
	return compare_to(other) > 0

func is_greater_equal(other: BigNumber) -> bool:
	return compare_to(other) >= 0

func is_less_than(other: BigNumber) -> bool:
	return compare_to(other) < 0

func is_less_equal(other: BigNumber) -> bool:
	return compare_to(other) <= 0

func is_equal(other: BigNumber) -> bool:
	return compare_to(other) == 0

func add(other: BigNumber) -> BigNumber:
	if is_zero():
		return other.duplicate_bn()
	if other.is_zero():
		return duplicate_bn()
	var exp_diff: int = exponent - other.exponent
	if exp_diff >= 15:
		return duplicate_bn()
	if exp_diff <= -15:
		return other.duplicate_bn()
	var new_m: float
	var new_e: int = exponent
	if exp_diff >= 0:
		new_m = mantissa + other.mantissa / pow(10.0, float(exp_diff))
	else:
		new_e = other.exponent
		new_m = mantissa / pow(10.0, float(-exp_diff)) + other.mantissa
	return BigNumber.new(new_m, new_e)

func sub(other: BigNumber) -> BigNumber:
	var neg_other := BigNumber.new(-other.mantissa, other.exponent)
	return add(neg_other)

func mul(scalar: float) -> BigNumber:
	return BigNumber.new(mantissa * scalar, exponent)

func mul_bn(other: BigNumber) -> BigNumber:
	return BigNumber.new(mantissa * other.mantissa, exponent + other.exponent)

func div(scalar: float) -> BigNumber:
	if is_zero_approx(scalar):
		return BigNumber.zero()
	return BigNumber.new(mantissa / scalar, exponent)

func div_bn(other: BigNumber) -> BigNumber:
	if other.is_zero():
		return BigNumber.zero()
	return BigNumber.new(mantissa / other.mantissa, exponent - other.exponent)

func to_float() -> float:
	if exponent > 308:
		return INF
	if exponent < -308:
		return 0.0
	return mantissa * pow(10.0, float(exponent))

func to_formatted(use_indian: bool = false) -> String:
	if is_zero():
		return "0"
	var sign_str: String = "-" if mantissa < 0.0 else ""
	var abs_m: float = absf(mantissa)

	if use_indian:
		return sign_str + _format_indian(abs_m, exponent)
	else:
		return sign_str + _format_short(abs_m, exponent)

func _format_short(m: float, e: int) -> String:
	if e < 3:
		var val: float = m * pow(10.0, float(e))
		if val >= 100.0:
			return str(roundi(val))
		elif val >= 10.0:
			return "%.1f" % val
		elif val >= 1.0:
			return "%.2f" % val
		else:
			return "%.2f" % val

	var suffix_index: int = e / 3
	if suffix_index >= SUFFIXES.size():
		return "%.2fe%d" % [m, e]

	var remainder: int = e % 3
	var display_val: float = m * pow(10.0, float(remainder))
	var suffix: String = SUFFIXES[suffix_index]

	if display_val >= 100.0:
		return "%.0f %s" % [display_val, suffix]
	elif display_val >= 10.0:
		return "%.1f %s" % [display_val, suffix]
	else:
		return "%.2f %s" % [display_val, suffix]

func _format_indian(m: float, e: int) -> String:
	if e < 3:
		var val: float = m * pow(10.0, float(e))
		return str(roundi(val)) if val >= 10.0 else "%.1f" % val
	elif e < 5:
		var val: float = m * pow(10.0, float(e - 3))
		return "%.2f K" % val
	elif e < 7:
		var val: float = m * pow(10.0, float(e - 5))
		return "%.2f Lakh" % val
	elif e < 9:
		var val: float = m * pow(10.0, float(e - 7))
		return "%.2f Crore" % val
	elif e < 11:
		var val: float = m * pow(10.0, float(e - 9))
		return "%.2f Arab" % val
	else:
		return _format_short(m, e)
