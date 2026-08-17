import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SharedGroup } from './entities/shared-group.entity';
import { SharedGroupMember } from './entities/shared-group-member.entity';
import { SharedGroupInvite } from './entities/shared-group-invite.entity';
import { SharedExpense } from './entities/shared-expense.entity';
import { SharedExpenseParticipant } from './entities/shared-expense-participant.entity';
import { SharedSettlement } from './entities/shared-settlement.entity';
import { SharedGroupSettings } from './entities/shared-group-settings.entity';
import { SharedExpenseApproval } from './entities/shared-expense-approval.entity';
import { SharedGroupsService } from './shared-groups.service';
import { SharedExpensesService } from './shared-expenses.service';
import { BalancesService } from './balances.service';
import { SettlementsService } from './settlements.service';
import { SharedGroupsController } from './shared-groups.controller';
import { SharedExpensesController } from './shared-expenses.controller';
import { CashModule } from '../cash/cash.module';
import { User } from '../users/user.entity';
import { UserNotificationPreferences } from '../users/user-notification-preferences.entity';
import { PushNotificationService } from '../../common/services/push-notification.service';
import { Insight } from '../insights/insight.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      SharedGroup,
      SharedGroupMember,
      SharedGroupInvite,
      SharedExpense,
      SharedExpenseParticipant,
      SharedSettlement,
      SharedGroupSettings,
      SharedExpenseApproval,
      User,
      UserNotificationPreferences,
      Insight,
    ]),
    CashModule,
  ],
  controllers: [SharedGroupsController, SharedExpensesController],
  providers: [
    SharedGroupsService,
    SharedExpensesService,
    BalancesService,
    SettlementsService,
    PushNotificationService,
  ],
})
export class SharedGroupsModule {}
