class_name BigNumber
extends RefCounted

# Currency value as mantissa × 10^exponent, so idle-game totals never hit
# float limits (~1e308) or lose integer precision. Immutable: every
# operation returns a new BigNumber, so callers can share instances safely.
# Invariant: mantissa is 0 (with exponent 0) or 1 <= |mantissa| < 10.

## Exponent gap beyond which the smaller operand can't change a double mantissa.
const PRECISION_DIGITS: int = 17
## Values below this are printed in full (1,234); from here on with suffixes (12.3K).
const SHORT_FORMAT_FROM_EXPONENT: int = 4
const SHORT_SUFFIXES: PackedStringArray = ["", "K", "M", "B", "T"]
const LETTERS: String = "abcdefghijklmnopqrstuvwxyz"
## Guards floor() against 4.56 being stored as 4.5599999...
const FORMAT_EPSILON: float = 1e-9

var mantissa: float = 0.0
var exponent: int = 0


func _init(m: float = 0.0, e: int = 0) -> void:
	mantissa = m
	exponent = e
	_normalize()


static func zero() -> BigNumber:
	return BigNumber.new(0.0, 0)


static func one() -> BigNumber:
	return BigNumber.new(1.0, 0)


static func from_float(value: float) -> BigNumber:
	return BigNumber.new(value, 0)


## 10^log_value, for values whose float form would overflow (e.g. r^n costs).
static func from_log10(log_value: float) -> BigNumber:
	var e: float = floorf(log_value)
	return BigNumber.new(pow(10.0, log_value - e), int(e))


static func from_dict(data: Dictionary) -> BigNumber:
	return BigNumber.new(float(data.get("m", 0.0)), int(data.get("e", 0)))


func to_dict() -> Dictionary:
	return {"m": mantissa, "e": exponent}


func _normalize() -> void:
	if mantissa == 0.0 or is_nan(mantissa) or is_inf(mantissa):
		mantissa = 0.0
		exponent = 0
		return
	var shift: int = int(floorf(log(absf(mantissa)) / log(10.0)))
	if shift != 0:
		mantissa /= pow(10.0, shift)
		exponent += shift
	# log() can land one step off at exact powers of ten.
	if absf(mantissa) >= 10.0:
		mantissa /= 10.0
		exponent += 1
	elif absf(mantissa) < 1.0:
		mantissa *= 10.0
		exponent -= 1


func is_zero() -> bool:
	return mantissa == 0.0


func is_negative() -> bool:
	return mantissa < 0.0


func to_float() -> float:
	return mantissa * pow(10.0, exponent)


func log10() -> float:
	if mantissa <= 0.0:
		return -INF
	return log(mantissa) / log(10.0) + exponent


# --- Arithmetic -------------------------------------------------------------

func add(other: BigNumber) -> BigNumber:
	if other.is_zero():
		return self
	if is_zero():
		return other
	var diff: int = exponent - other.exponent
	if diff > PRECISION_DIGITS:
		return self
	if diff < -PRECISION_DIGITS:
		return other
	if diff >= 0:
		return BigNumber.new(mantissa + other.mantissa / pow(10.0, diff), exponent)
	return BigNumber.new(mantissa / pow(10.0, -diff) + other.mantissa, other.exponent)


func subtract(other: BigNumber) -> BigNumber:
	return add(other.negated())


func multiply(other: BigNumber) -> BigNumber:
	return BigNumber.new(mantissa * other.mantissa, exponent + other.exponent)


func multiply_scalar(factor: float) -> BigNumber:
	return BigNumber.new(mantissa * factor, exponent)


## Division by zero returns zero rather than crashing the economy tick.
func divide(other: BigNumber) -> BigNumber:
	if other.is_zero():
		return BigNumber.zero()
	return BigNumber.new(mantissa / other.mantissa, exponent - other.exponent)


func negated() -> BigNumber:
	return BigNumber.new(-mantissa, exponent)


# --- Comparison -------------------------------------------------------------

## Returns -1, 0 or 1.
func compare(other: BigNumber) -> int:
	var sign_a: int = signi(int(signf(mantissa)))
	var sign_b: int = signi(int(signf(other.mantissa)))
	if sign_a != sign_b:
		return 1 if sign_a > sign_b else -1
	if sign_a == 0:
		return 0
	var result: int = 0
	if exponent != other.exponent:
		result = 1 if exponent > other.exponent else -1
	elif mantissa != other.mantissa:
		result = 1 if absf(mantissa) > absf(other.mantissa) else -1
	return result * sign_a


func is_greater_equal(other: BigNumber) -> bool:
	return compare(other) >= 0


func is_greater_than(other: BigNumber) -> bool:
	return compare(other) > 0


func is_less_than(other: BigNumber) -> bool:
	return compare(other) < 0


func is_equal(other: BigNumber) -> bool:
	return compare(other) == 0


# --- Formatting -------------------------------------------------------------

## Short: 1,234 → 12.3K → 4.56M → B → T → aa, ab… Indian: 12,345 → 1.23L → 4.56Cr.
## Values are floored, never rounded up, so the label never shows more cash than owned.
func to_formatted(use_indian: bool = false) -> String:
	if mantissa < 0.0:
		return "-" + negated().to_formatted(use_indian)
	if use_indian:
		return _format_indian()
	return _format_short()


func _format_short() -> String:
	if exponent < SHORT_FORMAT_FROM_EXPONENT:
		return _format_small(to_float(), false)
	var group: int = exponent / 3
	var suffix: String = _short_suffix(group)
	if suffix.is_empty():
		return _format_scientific()
	return _three_significant(mantissa * pow(10.0, exponent % 3)) + suffix


func _format_indian() -> String:
	const LAKH_EXPONENT: int = 5
	const CRORE_EXPONENT: int = 7
	const MAX_GROUPED_CRORE_EXPONENT: int = 12
	if exponent < LAKH_EXPONENT:
		return _format_small(to_float(), true)
	if exponent < CRORE_EXPONENT:
		return _three_significant(mantissa * pow(10.0, exponent - LAKH_EXPONENT)) + "L"
	if exponent < CRORE_EXPONENT + 3:
		return _three_significant(mantissa * pow(10.0, exponent - CRORE_EXPONENT)) + "Cr"
	if exponent < MAX_GROUPED_CRORE_EXPONENT:
		var crores: float = floorf(mantissa * pow(10.0, exponent - CRORE_EXPONENT) + FORMAT_EPSILON)
		return _group_digits(str(int(crores)), true) + "Cr"
	# Beyond a lakh crore Indian words stop being readable; use the short scale.
	return _format_short()


## Two-letter suffix after T: group 5 (1e15) = aa, 6 = ab, …
func _short_suffix(group: int) -> String:
	if group < SHORT_SUFFIXES.size():
		return SHORT_SUFFIXES[group]
	var index: int = group - SHORT_SUFFIXES.size()
	var count: int = LETTERS.length()
	if index >= count * count:
		return ""
	return LETTERS[index / count] + LETTERS[index % count]


func _format_scientific() -> String:
	return "%se%d" % [_truncate(mantissa, 2), exponent]


static func _three_significant(value: float) -> String:
	if value < 10.0:
		return _truncate(value, 2)
	if value < 100.0:
		return _truncate(value, 1)
	return _truncate(value, 0)


static func _truncate(value: float, decimals: int) -> String:
	var scale: float = pow(10.0, decimals)
	var floored: float = floorf(value * scale + FORMAT_EPSILON) / scale
	if decimals == 0:
		return str(int(floored))
	return ("%." + str(decimals) + "f") % floored


## Small values keep one decimal so a 0.5/s rate doesn't read as 0.
static func _format_small(value: float, indian: bool) -> String:
	const FRACTION_BELOW: float = 100.0
	var whole: float = floorf(value + FORMAT_EPSILON)
	if value < FRACTION_BELOW and value - whole > FORMAT_EPSILON * 10.0:
		var tenths: float = floorf(value * 10.0 + FORMAT_EPSILON) / 10.0
		if tenths > whole:
			return "%.1f" % tenths
	return _group_digits(str(int(whole)), indian)


## 1234567 → "1,234,567" (western) or "12,34,567" (Indian).
static func _group_digits(digits: String, indian: bool) -> String:
	if digits.length() <= 3:
		return digits
	var head: String = digits.substr(0, digits.length() - 3)
	var tail: String = digits.substr(digits.length() - 3)
	var group_size: int = 2 if indian else 3
	var parts: PackedStringArray = []
	while head.length() > group_size:
		parts.insert(0, head.substr(head.length() - group_size))
		head = head.substr(0, head.length() - group_size)
	parts.insert(0, head)
	parts.append(tail)
	return ",".join(parts)
