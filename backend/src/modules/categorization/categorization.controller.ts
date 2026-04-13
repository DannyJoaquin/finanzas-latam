import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Query,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';
import { ExpenseCategorizationService } from './expense-categorization.service';
import { CategorizationLearningService } from './categorization-learning.service';
import { CategorizationMetricsService } from './categorization-metrics.service';
import { CategorizationFeedbackDto } from './dto/categorization.dto';

@Controller('categorization')
export class CategorizationController {
  constructor(
    private categorizationService: ExpenseCategorizationService,
    private learningService: CategorizationLearningService,
    private metricsService: CategorizationMetricsService,
  ) {}

  /**
   * POST /categorization/feedback
   * Record that the user selected a specific category for a description.
   * Optionally marks the mapping as confirmed (remember = true).
   */
  @Post('feedback')
  @HttpCode(HttpStatus.NO_CONTENT)
  async feedback(
    @CurrentUser() user: User,
    @Body() dto: CategorizationFeedbackDto,
  ): Promise<void> {
    await this.learningService.recordFeedback(
      user.id,
      dto.description,
      dto.selectedCategoryId,
      { remember: dto.remember },
    );
  }

  /**
   * GET /categorization/stats
   * Returns accuracy metrics for the current user's auto-categorization history.
   */
  @Get('stats')
  getStats(
    @CurrentUser() user: User,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
  ) {
    return this.metricsService.getStats(user.id, {
      startDate: startDate ? new Date(startDate) : undefined,
      endDate: endDate ? new Date(endDate) : undefined,
    });
  }
}
