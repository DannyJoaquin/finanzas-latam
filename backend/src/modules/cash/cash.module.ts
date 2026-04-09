import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CashAccount } from './cash-account.entity';
import { CashTransaction } from './cash-transaction.entity';
import { CashController } from './cash.controller';
import { CashService } from './cash.service';

@Module({
  imports: [TypeOrmModule.forFeature([CashAccount, CashTransaction])],
  controllers: [CashController],
  providers: [CashService],
  exports: [CashService],
})
export class CashModule {}
