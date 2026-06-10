import { JUZS, TOTAL_VERSES } from "../../data/juz";

export { TOTAL_VERSES };

// heardMap shape: { [surahId]: number[] } — unique verse numbers heard.

export const totalVersesHeard = (heardMap) =>
  Object.values(heardMap || {}).reduce((sum, arr) => sum + arr.length, 0);

// Per-juz coverage: [{ juz, heard, total, ratio }] for the 30 juz grid.
export const juzCoverage = (heardMap) =>
  JUZS.map(({ juz, verses, mapping }) => {
    let heard = 0;
    for (const [surahId, range] of Object.entries(mapping)) {
      const heardInSurah = heardMap?.[surahId];
      if (!heardInSurah?.length) continue;
      const [start, end] = range.split("-").map(Number);
      for (const v of heardInSurah) {
        if (v >= start && v <= end) heard++;
      }
    }
    return { juz, heard, total: verses, ratio: heard / verses };
  });

// Projected completion date from recent pace (new verses/day over the last
// 14 logged days). Returns null when there's no measurable pace yet.
// dailyLog shape: { 'YYYY-MM-DD': newVersesCount }
export const projectedFinish = (heardMap, dailyLog) => {
  const heard = totalVersesHeard(heardMap);
  const remaining = TOTAL_VERSES - heard;
  if (remaining <= 0) return { complete: true };
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 14);
  let recent = 0;
  for (const [date, count] of Object.entries(dailyLog || {})) {
    if (new Date(date + "T00:00:00") >= cutoff) recent += count;
  }
  if (recent <= 0) return null;
  const perDay = recent / 14;
  const days = Math.ceil(remaining / perDay);
  if (days > 365 * 10) return null; // pace too slow to be a meaningful promise
  const finish = new Date();
  finish.setDate(finish.getDate() + days);
  return { complete: false, finish, perDay };
};

// Keep the daily log from growing forever — retain ~60 days.
export const pruneDailyLog = (dailyLog) => {
  const entries = Object.entries(dailyLog || {});
  if (entries.length <= 60) return dailyLog;
  const sorted = entries.sort(([a], [b]) => (a < b ? 1 : -1)).slice(0, 60);
  return Object.fromEntries(sorted);
};
