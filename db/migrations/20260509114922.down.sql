-- Phase 5 rollback: restore the pre-unification schema.
--
-- Logical inverse of 20260509114922.up.sql. Recreates user_notebook,
-- the old global-unique slug, the old course_notebook join, and the
-- (now-empty) post table; drops the new notebook table and users.handle.

DROP INDEX "key_course_notebook_course_id_position";
DROP INDEX "unique_course_notebook_course_id_notebook_id";
DROP TABLE "course_notebook";

DROP TABLE "notebook";

DROP INDEX "unique_course_author_id_slug";
DROP INDEX "key_course_visibility_status";
CREATE UNIQUE INDEX "unique_course_slug" ON "course" ("slug");

DROP INDEX "unique_users_handle";
ALTER TABLE "users" DROP COLUMN "handle";

CREATE TABLE "user_notebook" (
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
CREATE UNIQUE INDEX "unique_user_notebook_slug" ON "user_notebook" ("slug");
CREATE INDEX "key_user_notebook_status_created_at" ON "user_notebook" ("status", "created_at");
CREATE INDEX "key_user_notebook_author_id_created_at" ON "user_notebook" ("author_id", "created_at");

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

CREATE TABLE "post" (
    "id" UUID NOT NULL PRIMARY KEY,
    "title" VARCHAR(255) NOT NULL,
    "slug" VARCHAR(255) NOT NULL,
    "body" TEXT NOT NULL,
    "excerpt" VARCHAR(500),
    "status" VARCHAR(32) NOT NULL,
    "published_at" TIMESTAMPTZ,
    "author_id" UUID,
    "created_at" TIMESTAMPTZ,
    "updated_at" TIMESTAMPTZ
);
CREATE UNIQUE INDEX "unique_post_slug" ON "post" ("slug");
CREATE INDEX "key_post_status_created_at" ON "post" ("status", "created_at");
