// Leaderboard setup and helpers.
// All boards are authoritative: clients can READ them through the Nakama SDK
// (top 100, records around the player) but only the server can WRITE scores.

function createLeaderboard(nk: nkruntime.Nakama, logger: nkruntime.Logger, id: string, weekly: boolean): void {
  try {
    nk.leaderboardCreate(
      id,
      true, // authoritative
      nkruntime.SortOrder.DESCENDING,
      nkruntime.Operator.BEST,
      weekly ? TBE.WEEKLY_RESET_CRON : null,
      { weekly: weekly },
      true // enable ranks, needed for "your rank" and rank bands
    );
  } catch (err) {
    logger.error("leaderboardCreate failed for %s: %s", id, String(err));
    throw err;
  }
}

function setupGlobalLeaderboards(nk: nkruntime.Nakama, logger: nkruntime.Logger): void {
  createLeaderboard(nk, logger, TBE.BOARD_GLOBAL_ALLTIME, false);
  createLeaderboard(nk, logger, TBE.BOARD_GLOBAL_WEEKLY, true);
  logger.info("Global leaderboards ready");
}

// Country boards are created the first time a player from that country submits.
function ensureCountryLeaderboards(nk: nkruntime.Nakama, logger: nkruntime.Logger, country: string): void {
  const cacheKey = "tbe_country_boards_" + country;
  if (nk.localcacheGet(cacheKey)) {
    return;
  }
  const alltime = TBE.BOARD_COUNTRY_ALLTIME_PREFIX + country;
  const weekly = TBE.BOARD_COUNTRY_WEEKLY_PREFIX + country;
  const existing = nk.leaderboardsGetId([alltime, weekly]);
  const found: { [id: string]: boolean } = {};
  for (let i = 0; i < existing.length; i++) {
    found[existing[i].id] = true;
  }
  if (!found[alltime]) createLeaderboard(nk, logger, alltime, false);
  if (!found[weekly]) createLeaderboard(nk, logger, weekly, true);
  nk.localcachePut(cacheKey, true, 3600);
}

interface BoardRank {
  board: string;
  rank: number; // 0 if the player has no record
  total: number; // players on the board
}

function getOwnRank(nk: nkruntime.Nakama, boardId: string, userId: string): BoardRank {
  const list = nk.leaderboardRecordsList(boardId, [userId], 1);
  const own = list.ownerRecords && list.ownerRecords.length > 0 ? list.ownerRecords[0] : null;
  return {
    board: boardId,
    rank: own ? own.rank : 0,
    total: list.rankCount || 0,
  };
}

// What the client shows: exact rank inside the top 10,000, otherwise a percentile.
function presentRank(r: BoardRank): { [key: string]: any } {
  if (r.rank === 0) {
    return { board: r.board, ranked: false };
  }
  if (r.rank <= TBE.EXACT_RANK_LIMIT) {
    return { board: r.board, ranked: true, exact: true, rank: r.rank, total: r.total };
  }
  const pct = r.total > 0 ? Math.max(1, Math.ceil((r.rank / r.total) * 100)) : 100;
  return { board: r.board, ranked: true, exact: false, topPercent: pct, total: r.total };
}
