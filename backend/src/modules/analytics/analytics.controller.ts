import { Controller, Get, Query } from '@nestjs/common';
import { AnalyticsService } from './analytics.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';

@Controller('analytics')
export class AnalyticsController {
  constructor(private analyticsService: AnalyticsService) {}

  @Get('dashboard')
  getDashboard(@CurrentUser() user: User) {
    return this.analyticsService.getDashboard(user.id);
  }

  @Get('spending-trends')
  getSpendingTrends(@CurrentUser() user: User) {
    return this.analyticsService.getSpendingTrends(user.id);
  }

  @Get('anomalies')
  getAnomalies(@CurrentUser() user: User) {
    return this.analyticsService.detectAnomalies(user.id);
  }

  @Get('simulation')
  getSimulation(
    @CurrentUser() user: User,
    @Query('categoryId') categoryId: string,
    @Query('reductionPct') reductionPct: string,
  ) {
    return this.analyticsService.getSimulation(user.id, categoryId, parseFloat(reductionPct ?? '20'));
  }
}
