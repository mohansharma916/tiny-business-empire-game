// Unit tests for the pure logic (big numbers, plausibility, bands, weeks).
// Loads the compiled single-file build into a sandbox, the same way Nakama does.
// Run: npm test

const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const code = fs.readFileSync(path.join(__dirname, "..", "build", "index.js"), "utf8");
const g = { Math, JSON, Date, isFinite, Number, String, Error, encodeURIComponent };
vm.createContext(g);
vm.runInContext(code + "\n;this.__exports = { bigNormalize, bigParse, bigSub, bigCompare, bigToScore, bigFromScore, bigLog10, checkPlausibility, newScoreState, bandForRank, weekIdFor, isValidCountry, TBE };", g);
const raw = g.__exports;
// Objects created inside the sandbox have a different prototype; copy them before comparing.
const plain = (v) => (v && typeof v === "object" ? JSON.parse(JSON.stringify(v)) : v);
const L = {};
for (const k of Object.keys(raw)) {
  L[k] = typeof raw[k] === "function" ? (...args) => plain(raw[k](...args)) : raw[k];
}

const big = (m, e) => ({ m, e });
const HOUR = 3600 * 1000;

test("bigNormalize keeps mantissa in [1, 10)", () => {
  assert.deepStrictEqual(L.bigNormalize(12345, 0), { m: 1.2345, e: 4 });
  assert.deepStrictEqual(L.bigNormalize(0.5, 3), { m: 5, e: 2 });
  assert.deepStrictEqual(L.bigNormalize(0, 5), { m: 0, e: 0 });
});

test("bigParse rejects malformed input", () => {
  assert.strictEqual(L.bigParse(null), null);
  assert.strictEqual(L.bigParse({ m: 12, e: 3 }), null);
  assert.strictEqual(L.bigParse({ m: 0.5, e: 3 }), null);
  assert.strictEqual(L.bigParse({ m: 2, e: 1.5 }), null);
  assert.strictEqual(L.bigParse({ m: 2, e: -1 }), null);
  assert.deepStrictEqual(L.bigParse({ m: 2.5, e: 30 }), { m: 2.5, e: 30 });
});

test("bigSub and bigCompare", () => {
  const r = L.bigSub(big(5, 3), big(2, 3));
  assert.ok(Math.abs(r.m - 3) < 1e-9 && r.e === 3);
  assert.deepStrictEqual(L.bigSub(big(1, 3), big(2, 3)), { m: 0, e: 0 });
  assert.strictEqual(L.bigCompare(big(9.9, 10), big(1, 11)), -1);
});

test("score encoding sorts like the real values, beyond int64", () => {
  const values = [big(1, 3), big(9.99, 3), big(1, 4), big(2.5, 25), big(1, 100)];
  const encoded = values.map((v) => L.bigToScore(v));
  for (let i = 1; i < encoded.length; i++) {
    const a = encoded[i - 1];
    const b = encoded[i];
    assert.ok(b.score > a.score || (b.score === a.score && b.subscore > a.subscore));
  }
  const back = L.bigFromScore(25, 2.5e12);
  assert.ok(Math.abs(back.m - 2.5) < 1e-9 && back.e === 25);
});

test("first submission is capped", () => {
  const s = L.newScoreState();
  assert.strictEqual(L.checkPlausibility(s, big(5, 5), big(1, 2), Date.now()).ok, true);
  assert.strictEqual(L.checkPlausibility(s, big(1, 9), big(1, 2), Date.now()).ok, false);
});

test("earnings within income rate pass, impossible jumps fail", () => {
  const now = Date.now();
  const s = L.newScoreState();
  s.lifetime = big(1, 6);
  s.income = big(1, 3); // 1,000/s
  s.lastSubmitMs = now - HOUR;
  // 1 hour at 1,000/s = 3.6M; with tolerance 3 => ~10.8M allowed.
  assert.strictEqual(L.checkPlausibility(s, big(5, 6), big(1.2, 3), now).ok, true);
  assert.strictEqual(L.checkPlausibility(s, big(1, 9), big(1.2, 3), now).reason, "earnings_too_fast");
});

test("lifetime can't decrease and income can't explode", () => {
  const now = Date.now();
  const s = L.newScoreState();
  s.lifetime = big(1, 6);
  s.income = big(1, 3);
  s.lastSubmitMs = now - 5 * 60 * 1000;
  assert.strictEqual(L.checkPlausibility(s, big(1, 5), big(1, 3), now).reason, "lifetime_decreased");
  assert.strictEqual(L.checkPlausibility(s, big(1, 6), big(1, 9), now).reason, "income_growth_too_fast");
});

test("rank bands", () => {
  assert.strictEqual(L.bandForRank(0), 0);
  assert.strictEqual(L.bandForRank(20000), 0);
  assert.strictEqual(L.bandForRank(9999), 10000);
  assert.strictEqual(L.bandForRank(1000), 1000);
  assert.strictEqual(L.bandForRank(1001), 5000);
  assert.strictEqual(L.bandForRank(7), 10);
  assert.strictEqual(L.bandForRank(1), 1);
});

test("weeks roll over at Monday 00:00 IST", () => {
  // Sunday 2026-10-18 18:29 UTC = Sunday 23:59 IST; one minute later is Monday 00:00 IST.
  const before = Date.UTC(2026, 9, 18, 18, 29);
  const after = Date.UTC(2026, 9, 18, 18, 30);
  assert.strictEqual(L.weekIdFor(after) - L.weekIdFor(before), 1);
  assert.strictEqual(L.weekIdFor(after), L.weekIdFor(after + 6 * 24 * HOUR));
});

test("country codes", () => {
  assert.strictEqual(L.isValidCountry("IN"), true);
  assert.strictEqual(L.isValidCountry("in"), false);
  assert.strictEqual(L.isValidCountry("IND"), false);
});
