import { CalculationMethod, Coordinates, PrayerTimes } from "adhan";

export const PRAYER_ANCHORS = [
  { id: "fajr", label: "Fajr" },
  { id: "dhuhr", label: "Dhuhr" },
  { id: "asr", label: "Asr" },
  { id: "maghrib", label: "Maghrib" },
  { id: "isha", label: "Isha" },
  { id: "clock", label: "Set time" },
];

// Today's date as 'YYYY-MM-DD' in the device's local timezone.
export const todayLocalDate = (date = new Date()) =>
  new Intl.DateTimeFormat("en-CA", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);

export const deviceTimezone = () =>
  Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";

// Today's five prayer times as Dates for a coordinate pair.
export const getPrayerTimes = (lat, lng, date = new Date()) => {
  const times = new PrayerTimes(
    new Coordinates(lat, lng),
    date,
    CalculationMethod.MuslimWorldLeague(),
  );
  return {
    fajr: times.fajr,
    dhuhr: times.dhuhr,
    asr: times.asr,
    maghrib: times.maghrib,
    isha: times.isha,
  };
};

// The absolute time today's reminder should fire, or null if it can't be
// computed (prayer anchor without a stored location).
export const reminderTargetToday = ({ anchor, offsetMin, clockTime, lat, lng }) => {
  if (anchor === "clock") {
    const [h, m] = (clockTime || "07:00").split(":").map(Number);
    const t = new Date();
    t.setHours(h, m, 0, 0);
    return t;
  }
  if (lat == null || lng == null) return null;
  const prayerTime = getPrayerTimes(lat, lng)[anchor];
  if (!prayerTime) return null;
  return new Date(prayerTime.getTime() + (offsetMin || 0) * 60 * 1000);
};

export const formatClock = (date) =>
  date
    ? date.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })
    : "—";
