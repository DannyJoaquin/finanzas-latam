import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CreditCard } from './credit-card.entity';
import { CreditCardPayment } from './credit-card-payment.entity';
import { Expense } from '../expenses/expense.entity';
import { CreditCardsService } from './credit-cards.service';
import { CreditCardsController } from './credit-cards.controller';

@Module({
  imports: [TypeOrmModule.forFeature([CreditCard, CreditCardPayment, Expense])],
  controllers: [CreditCardsController],
  providers: [CreditCardsService],
  exports: [CreditCardsService],
})
export class CreditCardsModule {}
