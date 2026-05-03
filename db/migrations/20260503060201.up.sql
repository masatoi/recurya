CREATE TABLE "course" (
    "id" UUID NOT NULL PRIMARY KEY,
    "slug" VARCHAR(255) NOT NULL,
    "title" VARCHAR(255) NOT NULL,
    "summary" VARCHAR(500),
    "status" VARCHAR(32) NOT NULL,
    "published_at" TIMESTAMPTZ,
    "author_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ,
    "updated_at" TIMESTAMPTZ
);
CREATE UNIQUE INDEX "unique_course_slug" ON "course" ("slug");
CREATE INDEX "key_course_status_created_at" ON "course" ("status", "created_at");
CREATE INDEX "key_course_author_id_created_at" ON "course" ("author_id", "created_at");
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
