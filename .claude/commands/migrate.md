Use the rails-expert agent to create a Rails migration for: $ARGUMENTS

Steps:
1. Understand the schema change needed
2. Generate migration:
   ```bash
   docker compose run --rm rails rails generate migration <MigrationName>
   ```
3. Edit the generated migration file with proper change/up/down methods
4. Consider: indexes, foreign keys, null constraints, defaults
5. For JSONB columns (metadata pattern used in this project): use `jsonb` type
6. Run the migration:
   ```bash
   docker compose run --rm rails rails db:migrate
   ```
7. Verify with: `docker compose run --rm rails rails db:schema:dump` check

Remind about running tests after migration:
```bash
docker compose run --rm -e RAILS_ENV=test rails rails db:migrate
```
