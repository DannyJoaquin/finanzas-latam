import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { CreditCardsService } from './credit-cards.service';
import { CreateCreditCardDto, UpdateCreditCardDto, RecordCardPaymentDto } from './dto/credit-card.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';

@Controller('credit-cards')
export class CreditCardsController {
  constructor(private readonly creditCardsService: CreditCardsService) {}

  @Get()
  findAll(@CurrentUser() user: User) {
    return this.creditCardsService.findAll(user.id);
  }

  @Get('summary')
  getSummary(@CurrentUser() user: User) {
    return this.creditCardsService.getSummary(user.id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser() user: User, @Body() dto: CreateCreditCardDto) {
    return this.creditCardsService.create(user.id, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateCreditCardDto,
  ) {
    return this.creditCardsService.update(user.id, id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.creditCardsService.remove(user.id, id);
  }

  @Post(':id/payments')
  @HttpCode(HttpStatus.CREATED)
  recordPayment(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RecordCardPaymentDto,
  ) {
    return this.creditCardsService.recordPayment(user.id, id, dto);
  }

  @Get(':id/payments')
  getPayments(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.creditCardsService.getPaymentsForCard(user.id, id);
  }
}
