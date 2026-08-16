import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { RecurringExpensesService } from '../modules/recurring-expenses/recurring-expenses.service';

@Injectable()
export class RecurringExpensesJob {
  private readonly logger = new Logger(RecurringExpensesJob.name);

  constructor(private recurringExpensesService: RecurringExpensesService) {}

  /** Runs hourly so a missed date is generated without requiring an exact app opening time. */
  @Cron('0 * * * *')
  async run(): Promise<void> {
    try {
      const processed = await this.recurringExpensesService.processAllDue();
      this.logger.log(`Processed ${processed} recurring expense occurrence(s)`);
    } catch (error) {
      this.logger.error('Recurring expense processing failed', error);
    }
  }
}
