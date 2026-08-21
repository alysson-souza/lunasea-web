# Contributing

The browser app lives in `lib/`. Its Go server lives in `server/`.

## Requirements

- [FVM](https://fvm.app/), which installs the Flutter version pinned in `.fvmrc`
- Node.js 20 or later
- Go 1.23 or later for server changes
- Docker for running the complete app or checking the container image

## Set up

Install the pinned Flutter SDK and project dependencies:

```fish
fvm install
fvm flutter pub get
npm ci
npm run generate
```

Run `npm run generate` again after changing models, asset declarations, environment configuration, or localization files. Edit the source files, not the generated output.

## Run locally

Build and run the web app with its server:

```fish
docker compose -f compose.example.yaml up --build
```

Open [http://localhost:8080](http://localhost:8080).

## Check your change

For Flutter changes:

```fish
fvm flutter analyze
fvm flutter test
npm run build:web
```

For Go server changes:

```fish
go test ./...
```

If you changed the Dockerfile or Compose files, build the image:

```fish
docker buildx build --load --tag lunasea-web:local .
```

## Pull requests

Keep each pull request focused on one change. Add or update tests when behavior changes, and include screenshots when the interface changes.

Commit messages use Conventional Commits. The accepted types are `feat`, `fix`, `docs`, `chore`, `refactor`, and `release`.
