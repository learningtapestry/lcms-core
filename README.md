# LCMS COre

## Development

Create requried extensions inside the database and create development database

```shell
docker compose create db redis
docker compose start db
docker compose exec db sh -c "psql -U postgres -d template1 -c 'CREATE EXTENSION IF NOT EXISTS hstore;'"
docker compose exec db sh -c "psql -U postgres -c 'CREATE DATABASE lcms;'"
```

To build local image

```bash
docker build -f Dockerfile.dev -t lcms-core:3.4.7 .
```
