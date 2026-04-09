import { Controller, Delete, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Patch } from '@nestjs/common';
import { InsightsService } from './insights.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';

@Controller('insights')
export class InsightsController {
  constructor(private insightsService: InsightsService) {}

  @Get()
  findActive(@CurrentUser() user: User) {
    return this.insightsService.findActive(user.id);
  }

  @Patch(':id/read')
  @HttpCode(HttpStatus.NO_CONTENT)
  markRead(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.insightsService.markRead(user.id, id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  dismiss(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.insightsService.dismiss(user.id, id);
  }
}
