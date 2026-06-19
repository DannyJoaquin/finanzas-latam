import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';
import { SharedGroupsService } from './shared-groups.service';
import { BalancesService } from './balances.service';
import { SharedExpensesService } from './shared-expenses.service';
import { CreateGroupDto, JoinGroupDto } from './shared-groups.dto';

@Controller('shared-groups')
export class SharedGroupsController {
  constructor(
    private readonly groupsService: SharedGroupsService,
    private readonly balancesService: BalancesService,
    private readonly expensesService: SharedExpensesService,
  ) {}

  // ── Groups ────────────────────────────────────────────────────────────────

  @Post()
  createGroup(@CurrentUser() user: User, @Body() dto: CreateGroupDto) {
    return this.groupsService.createGroup(user.id, dto);
  }

  @Get()
  getMyGroups(@CurrentUser() user: User) {
    return this.groupsService.getUserGroups(user.id);
  }

  @Get('widget-summary')
  getWidgetSummary(@CurrentUser() user: User) {
    return this.balancesService.getWidgetSummary(user.id);
  }

  @Get('my-shared-expenses')
  getMySharedExpenses(@CurrentUser() user: User) {
    return this.expensesService.getMySharedExpenses(user.id);
  }

  @Get(':id')
  getGroup(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.groupsService.getGroupDetail(user.id, id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  deleteGroup(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.groupsService.deleteGroup(user.id, id);
  }

  // ── Members ────────────────────────────────────────────────────────────────

  @Post('join')
  joinGroup(@CurrentUser() user: User, @Body() dto: JoinGroupDto) {
    return this.groupsService.joinGroup(user.id, dto);
  }

  @Delete(':id/leave')
  @HttpCode(HttpStatus.NO_CONTENT)
  leaveGroup(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.groupsService.leaveGroup(user.id, id);
  }

  @Delete(':id/members/:userId')
  @HttpCode(HttpStatus.NO_CONTENT)
  removeMember(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('userId', ParseUUIDPipe) targetUserId: string,
  ) {
    return this.groupsService.removeMember(user.id, id, targetUserId);
  }

  // ── Balances ───────────────────────────────────────────────────────────────

  @Get(':id/balances')
  getGroupBalances(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.balancesService.getGroupBalances(user.id, id);
  }
}
