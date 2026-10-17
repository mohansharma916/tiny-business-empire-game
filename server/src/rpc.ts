// RPCs the Godot client calls through the Nakama SDK (client.rpc_async).
// Leaderboard READS (top 100, players around me) use the SDK's built-in leaderboard calls instead.

interface Profile {
  country: string;
  countryChanges: number;
  pushToken: string;
  pushPlatform: string;
  pushOptIn: boolean;
}

function readObject(nk: nkruntime.Nakama, userId: string, key: string): { [k: string]: any } | null {
  const objs = nk.storageRead([{ collection: TBE.STORAGE_COLLECTION, key: key, userId: userId }]);
  return objs.length > 0 ? objs[0].value : null;
}

function writeObject(nk: nkruntime.Nakama, userId: string, key: string, value: { [k: string]: any }): void {
  // Read permission 0 / write permission 0: only the server can see or change these.
  nk.storageWrite([
    { collection: TBE.STORAGE_COLLECTION, key: key, userId: userId, value: value, permissionRead: 0, permissionWrite: 0 },
  ]);
}

function loadProfile(nk: nkruntime.Nakama, userId: string): Profile {
  const v = readObject(nk, userId, TBE.STORAGE_KEY_PROFILE);
  return {
    country: v && v.country ? v.country : "",
    countryChanges: v && v.countryChanges ? v.countryChanges : 0,
    pushToken: v && v.pushToken ? v.pushToken : "",
    pushPlatform: v && v.pushPlatform ? v.pushPlatform : "",
    pushOptIn: !!(v && v.pushOptIn),
  };
}

function loadScoreState(nk: nkruntime.Nakama, userId: string): ScoreState {
  const v = readObject(nk, userId, TBE.STORAGE_KEY_SCORE);
  if (!v) {
    return newScoreState();
  }
  const s = newScoreState();
  s.lifetime = bigParse(v.lifetime) || BIG_ZERO;
  s.income = bigParse(v.income) || BIG_ZERO;
  s.lastSubmitMs = v.lastSubmitMs || 0;
  s.flagged = !!v.flagged;
  s.flagReason = v.flagReason || "";
  s.weekId = v.weekId || 0;
  s.weekStartLifetime = bigParse(v.weekStartLifetime) || BIG_ZERO;
  s.bandsNotified = v.bandsNotified || {};
  s.lastPushMs = v.lastPushMs || 0;
  return s;
}

function requireUser(ctx: nkruntime.Context): string {
  if (!ctx.userId) {
    throw new Error("Not authenticated");
  }
  return ctx.userId;
}

function parsePayload(payload: string): { [k: string]: any } {
  if (!payload) {
    return {};
  }
  try {
    return JSON.parse(payload);
  } catch (e) {
    throw new Error("Invalid JSON payload");
  }
}

// set_country {country: "IN"}
// Set once from store region / device locale, then the player may change it once.
const rpcSetCountry: nkruntime.RpcFunction = function (ctx, logger, nk, payload) {
  const userId = requireUser(ctx);
  const input = parsePayload(payload);
  const country = String(input.country || "").toUpperCase();
  if (!isValidCountry(country)) {
    throw new Error("Invalid country code");
  }
  const profile = loadProfile(nk, userId);
  if (profile.country === country) {
    return JSON.stringify({ ok: true, country: country });
  }
  if (profile.country !== "" && profile.countryChanges >= TBE.MAX_COUNTRY_CHANGES) {
    return JSON.stringify({ ok: false, error: "country_change_limit", country: profile.country });
  }
  if (profile.country !== "") {
    profile.countryChanges += 1;
  }
  profile.country = country;
  writeObject(nk, userId, TBE.STORAGE_KEY_PROFILE, profile);
  ensureCountryLeaderboards(nk, logger, country);
  return JSON.stringify({ ok: true, country: country });
};

// register_push_token {token: "...", platform: "android" | "ios", optIn: true}
// Call after the player grants notification permission (after their first milestone).
const rpcRegisterPushToken: nkruntime.RpcFunction = function (ctx, logger, nk, payload) {
  const userId = requireUser(ctx);
  const input = parsePayload(payload);
  const profile = loadProfile(nk, userId);
  profile.pushToken = typeof input.token === "string" ? input.token.substring(0, 4096) : "";
  profile.pushPlatform = input.platform === "ios" ? "ios" : "android";
  profile.pushOptIn = !!input.optIn && profile.pushToken !== "";
  writeObject(nk, userId, TBE.STORAGE_KEY_PROFILE, profile);
  return JSON.stringify({ ok: true, optIn: profile.pushOptIn });
};

// submit_score {lifetime: {m, e}, income: {m, e}}
// Client calls this every 5 minutes, on reaching a milestone, and when the app goes to the background.
const rpcSubmitScore: nkruntime.RpcFunction = function (ctx, logger, nk, payload) {
  const userId = requireUser(ctx);
  const input = parsePayload(payload);
  const lifetime = bigParse(input.lifetime);
  const income = bigParse(input.income);
  if (!lifetime || !income) {
    throw new Error("Invalid score payload");
  }

  const now = Date.now();
  const state = loadScoreState(nk, userId);
  const profile = loadProfile(nk, userId);

  // Rate limit: quietly ignore submissions that arrive too often.
  if (state.lastSubmitMs > 0 && now - state.lastSubmitMs < TBE.MIN_SUBMIT_INTERVAL_SECONDS * 1000) {
    return JSON.stringify({ ok: true, accepted: false, reason: "too_soon" });
  }

  // Weekly tracking: earnings this week = lifetime now - lifetime at the start of the week.
  const week = weekIdFor(now);
  if (state.weekId !== week) {
    state.weekId = week;
    state.weekStartLifetime = state.lastSubmitMs > 0 ? state.lifetime : lifetime;
  }

  const check = state.flagged ? { ok: false, reason: state.flagReason } : checkPlausibility(state, lifetime, income, now);
  if (!check.ok && !state.flagged) {
    state.flagged = true;
    state.flagReason = check.reason;
    logger.warn("Flagged user %s: %s", userId, check.reason);
  }

  state.lifetime = lifetime;
  state.income = income;
  state.lastSubmitMs = now;

  const ranks: { [k: string]: any }[] = [];

  // Flagged players keep playing but are quietly left off public boards.
  if (!state.flagged) {
    const weekly = bigSub(lifetime, state.weekStartLifetime);
    const all = bigToScore(lifetime);
    const wk = bigToScore(weekly);
    const username = ctx.username || "";
    const meta = { country: profile.country };

    const boards: { id: string; score: { score: number; subscore: number }; weekly: boolean }[] = [
      { id: TBE.BOARD_GLOBAL_ALLTIME, score: all, weekly: false },
      { id: TBE.BOARD_GLOBAL_WEEKLY, score: wk, weekly: true },
    ];
    if (profile.country) {
      ensureCountryLeaderboards(nk, logger, profile.country);
      boards.push({ id: TBE.BOARD_COUNTRY_ALLTIME_PREFIX + profile.country, score: all, weekly: false });
      boards.push({ id: TBE.BOARD_COUNTRY_WEEKLY_PREFIX + profile.country, score: wk, weekly: true });
    }

    let bestNewBand: { band: number; board: string; rank: number } | null = null;

    for (let i = 0; i < boards.length; i++) {
      const b = boards[i];
      nk.leaderboardRecordWrite(b.id, userId, username, b.score.score, b.score.subscore, meta);
      const r = getOwnRank(nk, b.id, userId);
      ranks.push(presentRank(r));

      // Rank-band celebration: once per band per board (per week for weekly boards).
      const band = bandForRank(r.rank);
      const key = b.weekly ? b.id + "#" + week : b.id;
      const previous = state.bandsNotified[key] || 0;
      if (band > 0 && (previous === 0 || band < previous)) {
        state.bandsNotified[key] = band;
        nk.notificationSend(userId, "rank_band", { board: b.id, band: band, rank: r.rank }, TBE.NOTIFY_RANK_BAND, null, true);
        if (!bestNewBand || band < bestNewBand.band) {
          bestNewBand = { band: band, board: b.id, rank: r.rank };
        }
      }
    }

    // At most one push per day, only for opted-in players, for their best new band.
    if (bestNewBand && profile.pushOptIn && now - state.lastPushMs >= TBE.PUSH_MIN_INTERVAL_MS) {
      const where = bestNewBand.board.indexOf("country") === 0 ? "in " + profile.country : "worldwide";
      const title = bestNewBand.band === 1 ? "You're #1 " + where + "!" : "You're in the Top " + bestNewBand.band + " " + where + "!";
      const body = "Your empire is now ranked #" + bestNewBand.rank + ". Keep building!";
      if (sendPush(ctx, logger, nk, profile.pushToken, title, body, { type: "rank_band", board: bestNewBand.board })) {
        state.lastPushMs = now;
      }
    }
  }

  writeObject(nk, userId, TBE.STORAGE_KEY_SCORE, state);
  return JSON.stringify({ ok: true, accepted: true, ranks: ranks });
};

// delete_my_account {confirm: true}
// Required by Google Play and the App Store for apps with accounts, and by GDPR / India's DPDP Act.
// Removes the account, its storage and its leaderboard records.
const rpcDeleteMyAccount: nkruntime.RpcFunction = function (ctx, logger, nk, payload) {
  const userId = requireUser(ctx);
  const input = parsePayload(payload);
  if (input.confirm !== true) {
    throw new Error("Deletion must be confirmed");
  }
  nk.accountDeleteId(userId, false);
  logger.info("Deleted account %s at user request", userId);
  return JSON.stringify({ ok: true });
};

// get_my_ranks {} -> rank or percentile on every board the player is on.
const rpcGetMyRanks: nkruntime.RpcFunction = function (ctx, logger, nk, payload) {
  const userId = requireUser(ctx);
  const profile = loadProfile(nk, userId);
  const ids = [TBE.BOARD_GLOBAL_ALLTIME, TBE.BOARD_GLOBAL_WEEKLY];
  if (profile.country) {
    ids.push(TBE.BOARD_COUNTRY_ALLTIME_PREFIX + profile.country);
    ids.push(TBE.BOARD_COUNTRY_WEEKLY_PREFIX + profile.country);
  }
  const ranks: { [k: string]: any }[] = [];
  for (let i = 0; i < ids.length; i++) {
    ranks.push(presentRank(getOwnRank(nk, ids[i], userId)));
  }
  return JSON.stringify({ ok: true, country: profile.country, ranks: ranks });
};
