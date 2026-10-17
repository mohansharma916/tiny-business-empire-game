// Minimal big-number helpers matching the client's BigNumber (mantissa + exponent).
// Value = m x 10^e, with 1 <= m < 10, or m = 0 for zero.
// Leaderboard scores are int64, which overflows near 9.2e18, so scores are encoded as
//   score = exponent, subscore = mantissa x 1e12
// Nakama sorts by score, then subscore, which matches numeric order.

interface BigNum {
  m: number;
  e: number;
}

const BIG_ZERO: BigNum = { m: 0, e: 0 };
const SUBSCORE_SCALE = 1e12;
const MAX_EXPONENT = 1000000;

function bigNormalize(m: number, e: number): BigNum {
  if (!isFinite(m) || m <= 0) {
    return { m: 0, e: 0 };
  }
  let exp = Math.floor(e);
  let man = m * Math.pow(10, e - exp);
  const shift = Math.floor(Math.log(man) / Math.LN10);
  man = man / Math.pow(10, shift);
  exp += shift;
  // Guard against floating-point edge cases like 9.9999999 -> 10.
  if (man >= 10) {
    man /= 10;
    exp += 1;
  }
  if (man < 1) {
    man *= 10;
    exp -= 1;
  }
  return { m: man, e: exp };
}

// Accepts {m, e} from the client and validates it. Returns null if malformed.
function bigParse(raw: any): BigNum | null {
  if (raw === null || typeof raw !== "object") {
    return null;
  }
  const m = Number(raw.m);
  const e = Number(raw.e);
  if (!isFinite(m) || !isFinite(e) || m < 0 || m >= 10 || Math.floor(e) !== e || e < 0 || e > MAX_EXPONENT) {
    return null;
  }
  if (m === 0) {
    return { m: 0, e: 0 };
  }
  if (m < 1) {
    return null;
  }
  return { m: m, e: e };
}

function bigIsZero(a: BigNum): boolean {
  return a.m === 0;
}

// log10 of the value; -Infinity for zero.
function bigLog10(a: BigNum): number {
  if (bigIsZero(a)) {
    return -Infinity;
  }
  return a.e + Math.log(a.m) / Math.LN10;
}

function bigCompare(a: BigNum, b: BigNum): number {
  if (bigIsZero(a) && bigIsZero(b)) return 0;
  if (bigIsZero(a)) return -1;
  if (bigIsZero(b)) return 1;
  if (a.e !== b.e) return a.e > b.e ? 1 : -1;
  if (a.m !== b.m) return a.m > b.m ? 1 : -1;
  return 0;
}

// a - b, floored at zero.
function bigSub(a: BigNum, b: BigNum): BigNum {
  if (bigCompare(a, b) <= 0) {
    return BIG_ZERO;
  }
  if (bigIsZero(b)) {
    return a;
  }
  const diff = a.e - b.e;
  if (diff > 15) {
    return a; // b is too small to matter at double precision
  }
  return bigNormalize(a.m - b.m * Math.pow(10, -diff), a.e);
}

function bigFromNumber(n: number): BigNum {
  return bigNormalize(n, 0);
}

function bigToScore(a: BigNum): { score: number; subscore: number } {
  if (bigIsZero(a)) {
    return { score: 0, subscore: 0 };
  }
  return { score: a.e, subscore: Math.floor(a.m * SUBSCORE_SCALE) };
}

function bigFromScore(score: number, subscore: number): BigNum {
  if (subscore <= 0) {
    return BIG_ZERO;
  }
  return bigNormalize(subscore / SUBSCORE_SCALE, score);
}
