// Score plausibility checks (PRD section 8, "Cheat prevention").
// Pure functions: no Nakama calls, so they can be unit-tested with plain Node.

interface ScoreState {
  lifetime: BigNum;
  income: BigNum;
  lastSubmitMs: number;
  flagged: boolean;
  flagReason: string;
  weekId: number;
  weekStartLifetime: BigNum;
  // Best (smallest) rank band already celebrated, per board id (weekly boards include the week id).
  bandsNotified: { [boardKey: string]: number };
  lastPushMs: number;
}

interface PlausibilityResult {
  ok: boolean;
  reason: string;
}

function newScoreState(): ScoreState {
  return {
    lifetime: BIG_ZERO,
    income: BIG_ZERO,
    lastSubmitMs: 0,
    flagged: false,
    flagReason: "",
    weekId: 0,
    weekStartLifetime: BIG_ZERO,
    bandsNotified: {},
    lastPushMs: 0,
  };
}

function checkPlausibility(prev: ScoreState, lifetime: BigNum, income: BigNum, nowMs: number): PlausibilityResult {
  // Lifetime earnings never go down.
  if (bigCompare(lifetime, prev.lifetime) < 0) {
    return { ok: false, reason: "lifetime_decreased" };
  }

  // First submission: cap what a new account may claim.
  if (prev.lastSubmitMs === 0) {
    if (bigLog10(lifetime) > TBE.FIRST_SUBMIT_MAX_LIFETIME_LOG10) {
      return { ok: false, reason: "first_submit_too_high" };
    }
    return { ok: true, reason: "" };
  }

  const elapsedSec = Math.max(1, (nowMs - prev.lastSubmitMs) / 1000);

  // Income growth limit.
  if (!bigIsZero(prev.income) && !bigIsZero(income)) {
    const hours = Math.max(TBE.MIN_GROWTH_WINDOW_HOURS, elapsedSec / 3600);
    const allowedIncomeLog = bigLog10(prev.income) + hours * (Math.log(TBE.MAX_INCOME_GROWTH_PER_HOUR) / Math.LN10);
    if (bigLog10(income) > allowedIncomeLog) {
      return { ok: false, reason: "income_growth_too_fast" };
    }
  }

  // Earnings since last submission vs. what the income rate allows.
  const delta = bigSub(lifetime, prev.lifetime);
  if (bigIsZero(delta) || bigCompare(delta, bigFromNumber(TBE.SLACK_ABS)) <= 0) {
    return { ok: true, reason: "" };
  }
  const maxIncome = bigCompare(prev.income, income) >= 0 ? prev.income : income;
  if (bigIsZero(maxIncome)) {
    return { ok: false, reason: "earnings_without_income" };
  }
  const allowedDeltaLog = bigLog10(maxIncome) + Math.log(elapsedSec * TBE.BOOST_TOLERANCE) / Math.LN10;
  if (bigLog10(delta) > allowedDeltaLog) {
    return { ok: false, reason: "earnings_too_fast" };
  }
  return { ok: true, reason: "" };
}

// Week number aligned to Monday 00:00 IST, matching TBE.WEEKLY_RESET_CRON.
function weekIdFor(nowMs: number): number {
  const days = Math.floor((nowMs + TBE.IST_OFFSET_MS) / 86400000);
  // 1970-01-01 was a Thursday; +3 makes weeks start on Monday.
  return Math.floor((days + 3) / 7);
}

// Smallest band the rank qualifies for, or 0 if outside all bands.
function bandForRank(rank: number): number {
  if (!rank || rank < 1) {
    return 0;
  }
  let best = 0;
  for (let i = 0; i < TBE.RANK_BANDS.length; i++) {
    const band = TBE.RANK_BANDS[i];
    if (rank <= band) {
      best = band;
    }
  }
  return best;
}

function isValidCountry(code: any): boolean {
  return typeof code === "string" && /^[A-Z]{2}$/.test(code);
}
