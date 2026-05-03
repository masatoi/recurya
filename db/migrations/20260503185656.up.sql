ALTER TABLE "course" ADD COLUMN "visibility" character varying(32) NOT NULL DEFAULT 'private';
ALTER TABLE "course" ALTER COLUMN "visibility" DROP DEFAULT;
ALTER TABLE "user_notebook" ADD COLUMN "visibility" character varying(32) NOT NULL DEFAULT 'private';
ALTER TABLE "user_notebook" ALTER COLUMN "visibility" DROP DEFAULT;

-- Backfill: existing published rows (single-axis status model) become public
-- under the new state x visibility model so the SICP course and any other
-- published notebook keeps being globally visible.
UPDATE "user_notebook" SET "visibility" = 'public' WHERE "status" = 'published';
UPDATE "course"        SET "visibility" = 'public' WHERE "status" = 'published';
