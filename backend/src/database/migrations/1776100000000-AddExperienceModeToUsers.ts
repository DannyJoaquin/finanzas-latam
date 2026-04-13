import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddExperienceModeToUsers1776100000000 implements MigrationInterface {
  name = 'AddExperienceModeToUsers1776100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE TYPE "public"."users_experience_mode_enum" AS ENUM ('simple', 'advanced')`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN "experience_mode" "public"."users_experience_mode_enum" NOT NULL DEFAULT 'advanced'`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "experience_mode"`);
    await queryRunner.query(`DROP TYPE "public"."users_experience_mode_enum"`);
  }
}
