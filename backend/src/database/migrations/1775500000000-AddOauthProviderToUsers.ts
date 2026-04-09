import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddOauthProviderToUsers1775500000000 implements MigrationInterface {
  name = 'AddOauthProviderToUsers1775500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "provider" character varying(50)`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "provider_id" character varying(255)`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" ALTER COLUMN "password_hash" DROP NOT NULL`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "idx_users_provider_id" ON "users" ("provider", "provider_id") WHERE provider IS NOT NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_users_provider_id"`);
    await queryRunner.query(`ALTER TABLE "users" ALTER COLUMN "password_hash" SET NOT NULL`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN IF EXISTS "provider_id"`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN IF EXISTS "provider"`);
  }
}
