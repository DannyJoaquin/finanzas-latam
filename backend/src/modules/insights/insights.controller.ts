import { Controller, Delete, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { InsightsService } from './insights.service';
import { InsightsGeneratorService } from './insights-generator.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';

@Controller('insights')
export class InsightsController {
  constructor(
    private insightsService: InsightsService,
    private insightsGenerator: InsightsGeneratorService,
  ) {}

  @Get()
  findActive(@CurrentUser() user: User) {
    return this.insightsService.findActive(user.id);
  }

  @Get('achievements')
  findAchievements(@CurrentUser() user: User) {
    return this.insightsService.findAchievements(user.id);
  }

  @Post('regenerate')
  @HttpCode(HttpStatus.NO_CONTENT)
  async regenerate(@CurrentUser() user: User) {
    await this.insightsGenerator.generateForUser(user.id);
  }

  @Patch(':id/read')
  @HttpCode(HttpStatus.NO_CONTENT)
  markRead(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.insightsService.markRead(user.id, id);
  }

  @Delete('dismiss-all')
  @HttpCode(HttpStatus.NO_CONTENT)
  dismissAll(@CurrentUser() user: User) {
    return this.insightsService.dismissAll(user.id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  dismiss(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.insightsService.dismiss(user.id, id);
  }
}
