# LCMS Core

## Development

Create required extensions inside the database and create development database

```shell
docker compose create db redis
docker compose start db
docker compose exec db sh -c "psql -U postgres -d template1 -c 'CREATE EXTENSION IF NOT EXISTS hstore;'"
docker compose exec db sh -c "psql -U postgres -c 'CREATE DATABASE lcms;'"
```

To build a local image

```bash
docker build -f Dockerfile.dev -t lcms-core:dev .
```

### Multi-platform build with buildx

To build a multi-platform image for both amd64 and arm64 architectures:

```bash
# Create a new builder instance (only needed once)
docker buildx create --name multiplatform-builder --use

# Build and push multi-platform image to registry
docker buildx build --platform linux/amd64,linux/arm64 \
  -f Dockerfile.dev \
  -t lcms-core:dev \
  --push .

# Or build and load locally (single platform only)
docker buildx build --platform linux/arm64 \
  -f Dockerfile.dev \
  -t lcms-core:dev \
  --load .
```

> **Note:** The `--push` flag requires authentication to a container registry. The `--load` flag only works with a single platform as Docker cannot load multi-platform images locally.


