import { BadRequestException, Body, Controller, Delete, Get, HttpCode, HttpStatus, Optional, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { InsightsService } from './insights.service';
import { InsightsGeneratorService } from './insights-generator.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PushNotificationService } from '../../common/services/push-notification.service';
import { User } from '../users/user.entity';

@Controller('insights')
export class InsightsController {
  constructor(
    private insightsService: InsightsService,
    private insightsGenerator: InsightsGeneratorService,
    @Optional() private pushService: PushNotificationService,
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

  /**
   * Sends a test push notification to the current user's registered device.
   * Use this to verify FCM is wired up end-to-end.
   * Body (optional): { title?: string; body?: string }
   */
  @Post('test-push')
  async testPush(
    @CurrentUser() user: User,
    @Body() dto: { title?: string; body?: string } = {},
  ) {
    if (!user.fcmToken) {
      throw new BadRequestException(
        'No FCM token registered for this account. Open the app once so it can register the device token.',
      );
    }
    if (!this.pushService) {
      throw new BadRequestException('PushNotificationService not available.');
    }
    const sent = await this.pushService.send({
      userId: user.id,
      fcmToken: user.fcmToken,
      title: dto.title ?? '🔔 Notificación de prueba',
      body: dto.body ?? 'Si ves esto, las notificaciones push funcionan correctamente.',
      data: { type: 'test' },
    });
    return { sent, firebaseReady: sent };
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
