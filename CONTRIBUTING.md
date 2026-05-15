# Contributing

This project is a PWA-only Flutter Web fork of LunaSea. This file collects local development commands only.

## Prerequisites

- macOS, Linux, or another environment that can run Flutter Web.
- [FVM](https://fvm.app/) for the pinned SDK in `.fvmrc`.
- Node.js 20+.
- Docker, when building or validating the container image.

## Setup

Initial dependency install:

```sh
fvm install
fvm flutter pub get
npm ci
```

Generated files:

```sh
npm run generate:environment
npm run generate:assets
npm run generate:build_runner
npm run generate:localization
```

All generators:

```sh
npm run generate
```

## Build and run

Web bundle:

```sh
npm run build:web
```

Docker image:

```sh
docker buildx build --load --tag lunasea-web:local .
```

Local container:

```sh
docker run --rm \
  -p 8080:8080 \
  -v lunasea-data:/data \
  lunasea-web:local
```

Local URL: `http://localhost:8080`.
