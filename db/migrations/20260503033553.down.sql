CREATE UNIQUE INDEX "users_provider_uid_unique" ON "users" ("provider", "provider_uid");
DROP TABLE "user_notebook";
