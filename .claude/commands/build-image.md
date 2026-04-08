Build the development Docker image locally for the current platform only (no push to registry).

Use this after updating gems (Gemfile/Gemfile.lock) or system dependencies when you only need the image on your own machine.

Run the following command:

```bash
docker buildx build \
  -f Dockerfile.dev \
  -t learningtapestry/lcms-core:dev \
  --load .
```

Notes:
- `--load` builds for the current platform only and loads the image into the local Docker daemon.
- Multi-platform builds cannot be combined with `--load`; use `/build-image-push` when a multi-arch image is needed.
- The resulting `learningtapestry/lcms-core:dev` tag is what `docker-compose.yml` references, so no further tagging is required.

After the build finishes, show the image info:

```bash
docker image ls learningtapestry/lcms-core:dev
```
