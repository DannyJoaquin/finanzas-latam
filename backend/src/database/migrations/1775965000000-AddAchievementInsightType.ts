import { MigrationInterface, QueryRunner } from "typeorm";

export class AddAchievementInsightType1775965000000 implements MigrationInterface {
    name = 'AddAchievementInsightType1775965000000'

    public async up(queryRunner: QueryRunner): Promise<void> {
        // Add 'achievement' to the insights type enum (Postgres requires this syntax)
        await queryRunner.query(`ALTER TYPE "public"."insights_type_enum" ADD VALUE IF NOT EXISTS 'achievement'`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        // Postgres does not support removing enum values natively.
        // A full recreation is required — not worth the risk; no rollback implemented.
    }
}
