# <img width="40px" src="./assets/images/branding_logo.png" alt="LunaSea"></img>&nbsp;&nbsp;LunaSea

LunaSea is a browser-based PWA for managing self-hosted media services.

This build is web-only. It supports Lidarr, Radarr, Sonarr, NZBGet, SABnzbd, Newznab-compatible search, NZBHydra2, Tautulli, and external links.

## Security Model

LunaSea Web does not include authentication or access control. Anyone who can reach the app can use the configured service connections.

Run it only on trusted networks, or place it behind a protected reverse proxy, Tailscale, Cloudflare Access, Authelia, Authentik, or another access-control layer. Do not expose it directly to the public internet.

## Run with Docker

Build the image:

```sh
docker buildx build --load --tag lunasea-web:local .
```

Run the container:

```sh
docker run --rm \
  -p 8080:8080 \
  -v lunasea-data:/data \
  lunasea-web:local
```

Open `http://localhost:8080`.

## Configure

Open Settings in the app and add each service.

Service URLs, credentials, profiles, preferences, indexers, external modules, dismissed banners, and logs are stored in the server-side SQLite database. Service traffic is proxied through the same origin as the app, which avoids browser CORS, mixed-content, and private-network restrictions.

## Data Storage

Application state is stored in `/data/lunasea.db`. Keep `/data` on a persistent volume if you want configuration to survive container replacement.

The browser does not own persistent LunaSea configuration. Reloading the page or clearing browser site data does not clear the app configuration. Removing the `/data` volume resets LunaSea Web to its default backend state.
