import { RecurringFrequency } from './recurring-expense.entity';
import {
  firstOccurrenceOnOrAfter,
  firstScheduledDate,
  formatDateOnly,
  nextOccurrenceAfter,
} from './recurring-expenses.schedule';

describe('recurring expense schedule', () => {
  it('clamps day 31 to the last day of February and restores day 31 next month', () => {
    const february = nextOccurrenceAfter(
      '2026-01-31',
      RecurringFrequency.MONTHLY,
      31,
    );
    const march = nextOccurrenceAfter(
      february,
      RecurringFrequency.MONTHLY,
      31,
    );

    expect(formatDateOnly(february)).toBe('2026-02-28');
    expect(formatDateOnly(march)).toBe('2026-03-31');
  });

  it('supports February 29 in a leap year', () => {
    expect(
      formatDateOnly(
        nextOccurrenceAfter('2028-01-31', RecurringFrequency.MONTHLY, 31),
      ),
    ).toBe('2028-02-29');
  });

  it('supports weekly and biweekly weekdays', () => {
    expect(
      formatDateOnly(firstScheduledDate('2026-08-16', RecurringFrequency.WEEKLY, 1)),
    ).toBe('2026-08-17');
    expect(
      formatDateOnly(nextOccurrenceAfter('2026-08-17', RecurringFrequency.BIWEEKLY, 1)),
    ).toBe('2026-08-31');
  });

  it('supports annual schedules and skips missed dates', () => {
    expect(
      formatDateOnly(nextOccurrenceAfter('2026-09-10', RecurringFrequency.ANNUAL, 10)),
    ).toBe('2027-09-10');
    expect(
      formatDateOnly(
        firstOccurrenceOnOrAfter(
          '2026-06-10',
          '2026-09-12',
          RecurringFrequency.MONTHLY,
          10,
        ),
      ),
    ).toBe('2026-10-10');
  });

  it.each([
    [RecurringFrequency.DAILY, '2026-08-11'],
    [RecurringFrequency.MONTHLY, '2026-09-10'],
    [RecurringFrequency.BIMONTHLY, '2026-10-10'],
    [RecurringFrequency.QUARTERLY, '2026-11-10'],
    [RecurringFrequency.SEMIANNUAL, '2027-02-10'],
  ])('advances %s correctly', (frequency, expected) => {
    expect(formatDateOnly(nextOccurrenceAfter('2026-08-10', frequency, 10))).toBe(expected);
  });
});
