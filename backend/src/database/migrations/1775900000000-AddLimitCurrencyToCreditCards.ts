import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddLimitCurrencyToCreditCards1775900000000 implements MigrationInterface {
  async up(qr: QueryRunner): Promise<void> {
    await qr.query(`
      ALTER TABLE credit_cards
      ADD COLUMN IF NOT EXISTS limit_currency VARCHAR(3) NOT NULL DEFAULT 'HNL'
    `);
  }

  async down(qr: QueryRunner): Promise<void> {
    await qr.query(`ALTER TABLE credit_cards DROP COLUMN IF EXISTS limit_currency`);
  }
}
