/**
 * Date-cycle utilities for biweekly / weekly / monthly pay periods.
 * Critical for LATAM pay cycles (quincenas: days 15 & 30).
 */

export interface Period {
  periodStart: Date;
  periodEnd: Date;
}

export type PayCycle = 'weekly' | 'biweekly' | 'monthly';

/**
 * Returns the current pay period boundaries given a reference date and cycle.
 * For biweekly: uses payDay1 (e.g. 15) and payDay2 (e.g. 30/EOM) as delimiters.
 */
export function getCurrentPeriod(
  refDate: Date,
  cycle: PayCycle,
  payDay1 = 15,
  payDay2 = 30,
): Period {
  const d = new Date(refDate);
  const year = d.getFullYear();
  const month = d.getMonth(); // 0-based
  const day = d.getDate();

  if (cycle === 'biweekly') {
    const eom = new Date(year, month + 1, 0).getDate();
    const p2 = Math.min(payDay2, eom);

    if (day <= payDay1) {
      const start = new Date(year, month, 1);
      const end = new Date(year, month, payDay1);
      return { periodStart: start, periodEnd: end };
    } else {
      const start = new Date(year, month, payDay1 + 1);
      const end = new Date(year, month, p2);
      return { periodStart: start, periodEnd: end };
    }
  }

  if (cycle === 'monthly') {
    const start = new Date(year, month, 1);
    const end = new Date(year, month + 1, 0);
    return { periodStart: start, periodEnd: end };
  }

  // weekly: Monday–Sunday
  const dayOfWeek = d.getDay(); // 0=sun
  const diffToMonday = dayOfWeek === 0 ? -6 : 1 - dayOfWeek;
  const start = new Date(d);
  start.setDate(d.getDate() + diffToMonday);
  const end = new Date(start);
  end.setDate(start.getDate() + 6);
  return { periodStart: start, periodEnd: end };
}

/**
 * Returns the next pay-period boundaries (the one after current).
 */
export function getNextPeriod(
  refDate: Date,
  cycle: PayCycle,
  payDay1 = 15,
  payDay2 = 30,
): Period {
  const current = getCurrentPeriod(refDate, cycle, payDay1, payDay2);
  const nextRef = new Date(current.periodEnd);
  nextRef.setDate(nextRef.getDate() + 1);
  return getCurrentPeriod(nextRef, cycle, payDay1, payDay2);
}

/**
 * How many days remain in the current period including today.
 */
export function daysRemainingInPeriod(refDate: Date, periodEnd: Date): number {
  const end = new Date(periodEnd);
  end.setHours(23, 59, 59, 999);
  const diff = end.getTime() - refDate.getTime();
  return Math.max(0, Math.ceil(diff / (1000 * 60 * 60 * 24)));
}

/**
 * Formats a date as YYYY-MM-DD string (no timezone shift).
 */
export function toDateString(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}
