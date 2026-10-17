// Server-side tuning for leaderboards, score validation and notifications.
// Starting values only. Keep them in sync with docs/PRD.md section 8.
// This project compiles to ONE script for Nakama (no imports/exports), so files share globals.

const TBE = {
  // Leaderboard ids. Country boards append "_<ISO country code>", e.g. "country_alltime_IN".
  BOARD_GLOBAL_ALLTIME: "global_alltime",
  BOARD_GLOBAL_WEEKLY: "global_weekly",
  BOARD_COUNTRY_ALLTIME_PREFIX: "country_alltime_",
  BOARD_COUNTRY_WEEKLY_PREFIX: "country_weekly_",

  // Weekly reset: Monday 00:00 IST = Sunday 18:30 UTC. Nakama cron runs in UTC.
  WEEKLY_RESET_CRON: "30 18 * * 0",
  IST_OFFSET_MS: 5.5 * 60 * 60 * 1000,

  // Exact rank shown inside this rank; percentile beyond it.
  EXACT_RANK_LIMIT: 10000,

  // Rank bands that trigger a celebration (smallest = best).
  RANK_BANDS: [10000, 5000, 1000, 500, 100, 50, 10, 1],

  // Score submission rules.
  MIN_SUBMIT_INTERVAL_SECONDS: 60,
  // Max earnings a brand-new player may report on their first submission.
  FIRST_SUBMIT_MAX_LIFETIME_LOG10: 7, // 1e7
  // Earnings between two submissions may not exceed:
  //   max(previous income/s, new income/s) x seconds elapsed x BOOST_TOLERANCE
  // BOOST_TOLERANCE covers the 2x ad boost, 1.2x tap boost, offline collection and rounding.
  BOOST_TOLERANCE: 3.0,
  // Small absolute allowance so tiny early-game values never get flagged.
  SLACK_ABS: 5000,
  // Income/s may not grow faster than this factor per hour of real time.
  MAX_INCOME_GROWTH_PER_HOUR: 50,
  // Shortest interval used for the income-growth check (5 minutes), so quick resubmits aren't punished.
  MIN_GROWTH_WINDOW_HOURS: 5 / 60,

  // Push notifications.
  PUSH_MIN_INTERVAL_MS: 24 * 60 * 60 * 1000, // at most 1 per day

  // Nakama in-app notification codes (client switches on these).
  NOTIFY_RANK_BAND: 100,

  // Storage.
  STORAGE_COLLECTION: "tbe_player",
  STORAGE_KEY_SCORE: "score_state",
  STORAGE_KEY_PROFILE: "profile",

  // Country can be set once, then changed once.
  MAX_COUNTRY_CHANGES: 1,
};
