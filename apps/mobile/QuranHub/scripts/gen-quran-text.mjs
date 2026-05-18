// Generates the bundled offline corpus: every surah's Arabic (Uthmani) text
// plus the Khattab (eng-mustafakhattaba) English translation — the exact two
// sources the PWA fetched at runtime. Output: Sources/Resources/Data/quran-text.json
//
//   { "1": { "verses": [ { "n": 1, "ar": "...", "en": "..." }, ... ] }, ... }
//
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT = join(__dirname, "..", "Sources", "Resources", "Data", "quran-text.json");

const getJSON = async (url) => {
  for (let attempt = 0; attempt < 4; attempt++) {
    try {
      const r = await fetch(url, { headers: { "User-Agent": "QuranHub-build" } });
      if (!r.ok) throw new Error(`${r.status} ${url}`);
      return await r.json();
    } catch (e) {
      if (attempt === 3) throw e;
      await new Promise((res) => setTimeout(res, 800 * (attempt + 1)));
    }
  }
};

const main = async () => {
  // 1. Arabic Uthmani — single call returns all 6236 verses.
  console.log("Fetching Arabic (Uthmani)…");
  const ar = await getJSON("https://api.quran.com/api/v4/quran/verses/uthmani");
  const arByKey = {};
  for (const v of ar.verses) arByKey[v.verse_key] = v.text_uthmani;

  // 2. Khattab English — combined edition file.
  console.log("Fetching English (Khattab)…");
  let enByKey = {};
  try {
    const en = await getJSON(
      "https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/eng-mustafakhattaba.json",
    );
    const list = en.quran || en.chapter || [];
    for (const t of list) enByKey[`${t.chapter}:${t.verse}`] = clean(t.text);
  } catch {
    console.log("Combined edition failed — falling back to per-surah…");
    for (let s = 1; s <= 114; s++) {
      const j = await getJSON(
        `https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/eng-mustafakhattaba/${s}.json`,
      );
      for (const t of j.chapter) enByKey[`${s}:${t.verse}`] = clean(t.text);
      process.stdout.write(`\rEN ${s}/114`);
    }
    console.log();
  }

  function clean(t) {
    return (t || "")
      .replace(/<sup[^>]*>.*?<\/sup>/gi, "")
      .replace(/<[^>]*>/g, "")
      .trim();
  }

  // 3. Merge keyed by surah → ordered verse list.
  const counts = {}; // surah → max ayah
  for (const key of Object.keys(arByKey)) {
    const [s, a] = key.split(":").map(Number);
    counts[s] = Math.max(counts[s] || 0, a);
  }

  const out = {};
  for (let s = 1; s <= 114; s++) {
    const verses = [];
    for (let a = 1; a <= counts[s]; a++) {
      const k = `${s}:${a}`;
      verses.push({
        n: a,
        ar: arByKey[k] || "",
        en: enByKey[k] || "Translation not available",
      });
    }
    out[s] = { verses };
  }

  writeFileSync(OUT, JSON.stringify(out));
  const totalVerses = Object.values(out).reduce((n, c) => n + c.verses.length, 0);
  console.log(`Wrote ${OUT} — ${Object.keys(out).length} surahs, ${totalVerses} verses`);
};

main().catch((e) => {
  console.error("FAILED:", e);
  process.exit(1);
});
