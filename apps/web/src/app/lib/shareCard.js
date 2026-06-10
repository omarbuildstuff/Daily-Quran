// Render a verse card straight onto a <canvas> — no DOM rasterization, no
// stylesheet/font embedding (the html-to-image approach broke on the page's
// cross-origin styles). The browser's own text engine shapes the Arabic.
// verse: { surahName, verseKey, text, translation }

const WIDTH = 540;
const PAD = 48;
const SCALE = 2;

const wrapLines = (ctx, text, maxWidth) => {
  const words = String(text || "").trim().split(/\s+/).filter(Boolean);
  const lines = [];
  let line = "";
  for (const word of words) {
    const candidate = line ? `${line} ${word}` : word;
    if (ctx.measureText(candidate).width > maxWidth && line) {
      lines.push(line);
      line = word;
    } else {
      line = candidate;
    }
  }
  if (line) lines.push(line);
  return lines;
};

const ARABIC_FONT = '34px "Thmanyah Serif Display", Georgia, serif';
const TRANSLATION_FONT = 'italic 17px "Thmanyah Serif Display", Georgia, serif';
const LABEL_FONT = 'bold 11px Inter, sans-serif';

export const shareVerse = async (verse) => {
  // Make sure the display faces are loaded before measuring/drawing.
  try {
    await Promise.all([
      document.fonts.load(ARABIC_FONT, verse.text),
      document.fonts.load(TRANSLATION_FONT, "a"),
      document.fonts.ready,
    ]);
  } catch {
    // Fall through — serif fallbacks still render fine
  }

  const maxWidth = WIDTH - PAD * 2;
  const measure = document.createElement("canvas").getContext("2d");

  measure.font = ARABIC_FONT;
  const arabicLines = wrapLines(measure, verse.text, maxWidth);
  const arabicLineHeight = 64;

  measure.font = TRANSLATION_FONT;
  const translationLines = wrapLines(measure, verse.translation, maxWidth);
  const translationLineHeight = 28;

  const headerY = 64;
  const arabicTop = headerY + 44;
  const translationTop =
    arabicTop + arabicLines.length * arabicLineHeight + (translationLines.length ? 24 : 0);
  const footerY = translationTop + translationLines.length * translationLineHeight + 48;
  const height = footerY + 52;

  const canvas = document.createElement("canvas");
  canvas.width = WIDTH * SCALE;
  canvas.height = height * SCALE;
  const ctx = canvas.getContext("2d");
  ctx.scale(SCALE, SCALE);

  // Warm cream background with two soft gold glows
  ctx.fillStyle = "#faf8f2";
  ctx.fillRect(0, 0, WIDTH, height);
  let glow = ctx.createRadialGradient(WIDTH * 0.85, height * 0.08, 0, WIDTH * 0.85, height * 0.08, height * 0.5);
  glow.addColorStop(0, "rgba(196,154,80,0.14)");
  glow.addColorStop(1, "rgba(196,154,80,0)");
  ctx.fillStyle = glow;
  ctx.fillRect(0, 0, WIDTH, height);
  glow = ctx.createRadialGradient(WIDTH * 0.1, height * 0.95, 0, WIDTH * 0.1, height * 0.95, height * 0.45);
  glow.addColorStop(0, "rgba(196,154,80,0.10)");
  glow.addColorStop(1, "rgba(196,154,80,0)");
  ctx.fillStyle = glow;
  ctx.fillRect(0, 0, WIDTH, height);

  // Gold top bar
  ctx.fillStyle = "#c49a50";
  ctx.fillRect(0, 0, WIDTH, 6);

  // Header label
  ctx.font = LABEL_FONT;
  if ("letterSpacing" in ctx) ctx.letterSpacing = "3px";
  ctx.fillStyle = "#a89f8d";
  ctx.textAlign = "left";
  ctx.fillText(
    `SURAH ${String(verse.surahName || "").toUpperCase()}  •  ${verse.verseKey}`,
    PAD,
    headerY,
  );
  if ("letterSpacing" in ctx) ctx.letterSpacing = "0px";

  // Arabic text, right-aligned RTL
  ctx.font = ARABIC_FONT;
  ctx.fillStyle = "#1a1a1a";
  ctx.textAlign = "right";
  ctx.direction = "rtl";
  arabicLines.forEach((line, i) => {
    ctx.fillText(line, WIDTH - PAD, arabicTop + (i + 1) * arabicLineHeight - 20);
  });

  // Translation
  ctx.direction = "ltr";
  ctx.textAlign = "left";
  ctx.font = TRANSLATION_FONT;
  ctx.fillStyle = "#6b6354";
  translationLines.forEach((line, i) => {
    ctx.fillText(line, PAD, translationTop + (i + 1) * translationLineHeight);
  });

  // Footer: hairline + wordmark
  ctx.strokeStyle = "rgba(196,154,80,0.4)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(PAD, footerY);
  ctx.lineTo(WIDTH - PAD - 110, footerY);
  ctx.stroke();
  ctx.font = LABEL_FONT;
  if ("letterSpacing" in ctx) ctx.letterSpacing = "3px";
  ctx.fillStyle = "#c49a50";
  ctx.textAlign = "right";
  ctx.fillText("QURAN HUB", WIDTH - PAD, footerY + 4);

  const blob = await new Promise((resolve, reject) => {
    canvas.toBlob(
      (b) => (b ? resolve(b) : reject(new Error("Canvas export failed"))),
      "image/png",
    );
  });
  const fileName = `quran-${String(verse.verseKey).replace(":", "-")}.png`;
  const file = new File([blob], fileName, { type: "image/png" });

  if (navigator.canShare?.({ files: [file] })) {
    try {
      await navigator.share({
        files: [file],
        title: `Surah ${verse.surahName} ${verse.verseKey}`,
      });
      return "shared";
    } catch (err) {
      if (err?.name === "AbortError") return "cancelled";
      // Fall through to download on share failures
    }
  }

  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = fileName;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
  return "downloaded";
};
