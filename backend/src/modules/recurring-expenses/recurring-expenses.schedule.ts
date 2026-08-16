import { RecurringFrequency } from './recurring-expense.entity';

export function dateOnly(value: Date | string): Date {
  if (typeof value === 'string') {
    const [year, month, day] = value.slice(0, 10).split('-').map(Number);
    return new Date(Date.UTC(year, month - 1, day));
  }

  return new Date(Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()));
}

export function formatDateOnly(value: Date | string): string {
  const date = dateOnly(value);
  return [
    date.getUTCFullYear(),
    String(date.getUTCMonth() + 1).padStart(2, '0'),
    String(date.getUTCDate()).padStart(2, '0'),
  ].join('-');
}

export function addDays(value: Date, days: number): Date {
  const result = dateOnly(value);
  result.setUTCDate(result.getUTCDate() + days);
  return result;
}

export function daysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

function monthStep(frequency: RecurringFrequency): number | null {
  switch (frequency) {
    case RecurringFrequency.MONTHLY:
      return 1;
    case RecurringFrequency.BIMONTHLY:
      return 2;
    case RecurringFrequency.QUARTERLY:
      return 3;
    case RecurringFrequency.SEMIANNUAL:
      return 6;
    case RecurringFrequency.ANNUAL:
      return 12;
    default:
      return null;
  }
}

function dateWithExecutionDay(year: number, month: number, executionDay: number): Date {
  const lastDay = daysInMonth(year, month);
  return new Date(Date.UTC(year, month - 1, Math.min(executionDay, lastDay)));
}

function isoWeekday(value: Date): number {
  const day = dateOnly(value).getUTCDay();
  return day === 0 ? 7 : day;
}

export function firstScheduledDate(
  startDate: Date | string,
  frequency: RecurringFrequency,
  executionDay: number,
): Date {
  const anchor = dateOnly(startDate);

  if (frequency === RecurringFrequency.DAILY) return anchor;

  if (frequency === RecurringFrequency.WEEKLY || frequency === RecurringFrequency.BIWEEKLY) {
    const delta = (executionDay - isoWeekday(anchor) + 7) % 7;
    return addDays(anchor, delta);
  }

  const months = monthStep(frequency)!;
  let candidate = dateWithExecutionDay(
    anchor.getUTCFullYear(),
    anchor.getUTCMonth() + 1,
    executionDay,
  );
  if (candidate < anchor) {
    const nextMonth = new Date(Date.UTC(anchor.getUTCFullYear(), anchor.getUTCMonth() + months, 1));
    candidate = dateWithExecutionDay(
      nextMonth.getUTCFullYear(),
      nextMonth.getUTCMonth() + 1,
      executionDay,
    );
  }
  return candidate;
}

export function nextOccurrenceAfter(
  scheduledDate: Date | string,
  frequency: RecurringFrequency,
  executionDay: number,
): Date {
  const current = dateOnly(scheduledDate);

  if (frequency === RecurringFrequency.DAILY) return addDays(current, 1);

  if (frequency === RecurringFrequency.WEEKLY) {
    const delta = (executionDay - isoWeekday(current) + 7) % 7 || 7;
    return addDays(current, delta);
  }

  if (frequency === RecurringFrequency.BIWEEKLY) return addDays(current, 14);

  const months = monthStep(frequency)!;
  const nextMonth = new Date(Date.UTC(current.getUTCFullYear(), current.getUTCMonth() + months, 1));
  return dateWithExecutionDay(
    nextMonth.getUTCFullYear(),
    nextMonth.getUTCMonth() + 1,
    executionDay,
  );
}

export function firstOccurrenceOnOrAfter(
  startDate: Date | string,
  today: Date | string,
  frequency: RecurringFrequency,
  executionDay: number,
): Date {
  let next = firstScheduledDate(startDate, frequency, executionDay);
  const currentDay = dateOnly(today);
  let guard = 0;

  while (next < currentDay && guard < 10000) {
    next = nextOccurrenceAfter(next, frequency, executionDay);
    guard++;
  }

  return next;
}
