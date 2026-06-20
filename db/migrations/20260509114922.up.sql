-- Phase 5: Notebook unification migration.
--
-- Brings the PostgreSQL schema in line with the Lisp models from
-- Phase 3 / Phase 4:
--
--   * Drop legacy `post` table (model deleted in Phase 3).
--   * Drop legacy `user_notebook` (and its old `course_notebook` join)
--     in favor of the new `notebook` table.
--   * Add `users.handle` (NOT NULL UNIQUE).
--   * Per-author slug uniqueness on `course` and `notebook`.
--   * Add (visibility, status) composite indexes.
--
-- IMPORTANT: This migration is not data-preserving. It assumes the
-- affected tables (users, user_notebook, course, course_notebook, post)
-- are empty (early-development TRUNCATE). The Phase 5 step in
-- docs/notebook-unification.md performs that TRUNCATE before applying.

DROP TABLE IF EXISTS "course_notebook";
DROP TABLE IF EXISTS "user_notebook";
DROP TABLE IF EXISTS "post";

ALTER TABLE "users" ADD COLUMN "handle" character varying(64) NOT NULL;
CREATE UNIQUE INDEX "unique_users_handle" ON "users" ("handle");
DROP INDEX "unique_course_slug";
CREATE INDEX "key_course_visibility_status" ON "course" ("visibility", "status");
CREATE UNIQUE INDEX "unique_course_author_id_slug" ON "course" ("author_id", "slug");
CREATE TABLE "notebook" (
    "id" UUID NOT NULL PRIMARY KEY,
    "slug" VARCHAR(255) NOT NULL,
    "title" VARCHAR(255) NOT NULL,
    "summary" VARCHAR(500),
    "body_md" TEXT NOT NULL,
    "cells" JSONB NOT NULL,
    "status" VARCHAR(32) NOT NULL,
    "visibility" VARCHAR(32) NOT NULL,
    "published_at" TIMESTAMPTZ,
    "author_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ,
    "updated_at" TIMESTAMPTZ
);
CREATE UNIQUE INDEX "unique_notebook_author_id_slug" ON "notebook" ("author_id", "slug");
CREATE INDEX "key_notebook_status_created_at" ON "notebook" ("status", "created_at");
CREATE INDEX "key_notebook_author_id_created_at" ON "notebook" ("author_id", "created_at");
CREATE INDEX "key_notebook_visibility_status" ON "notebook" ("visibility", "status");
CREATE TABLE "course_notebook" (
    "id" BIGSERIAL NOT NULL PRIMARY KEY,
    "course_id" UUID NOT NULL,
    "notebook_id" UUID NOT NULL,
    "position" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ,
    "updated_at" TIMESTAMPTZ
);
CREATE UNIQUE INDEX "unique_course_notebook_course_id_notebook_id" ON "course_notebook" ("course_id", "notebook_id");
CREATE INDEX "key_course_notebook_course_id_position" ON "course_notebook" ("course_id", "position");
