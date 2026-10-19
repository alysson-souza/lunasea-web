# <img src="./assets/images/branding_logo.png" width="40" alt=""> LunaSea Web

[![Build](https://github.com/alysson-souza/lunasea-web/actions/workflows/build.yml/badge.svg)](https://github.com/alysson-souza/lunasea-web/actions/workflows/build.yml)
[![Latest release](https://img.shields.io/github/v/release/alysson-souza/lunasea-web)](https://github.com/alysson-souza/lunasea-web/releases/latest)
[![License](https://img.shields.io/github/license/alysson-souza/lunasea-web)](LICENSE.md)

LunaSea Web is a browser-based PWA for managing Lidarr, Radarr, Sonarr, download clients, indexers, and Tautulli. It is a web-only fork of [LunaSea](https://github.com/jagandeepbrar/lunasea).

## Features

- Lidarr, Radarr, and Sonarr management
- NZBGet and SABnzbd monitoring
- Newznab-compatible search, including NZBHydra2
- Tautulli integration and custom external links
- Multiple service instances
- Consolidated Radarr, Sonarr, and SABnzbd views

The consolidated SABnzbd view combines jobs into one queue and one history list, with source labels on each job. History supports search and failed-job filtering. Server controls target one selected instance; server statistics and queue reordering remain in the individual instance view.

Use the title menu to switch between All Instances and a server without a page transition. The selected Queue or History tab stays selected. Background polling is silent; pull down to refresh explicitly.

## Quick start

You need [Docker](https://docs.docker.com/get-docker/) with Docker Compose.

```fish
git clone https://github.com/alysson-souza/lunasea-web.git
cd lunasea-web
docker compose up -d
```

Open [http://localhost:8080](http://localhost:8080), then add your services in Settings.

## Security

LunaSea Web has no login screen or access control. Do not expose it directly to the public internet. For remote access, put it behind authentication or use a trusted private network such as Tailscale.

## Contributing

Before opening a pull request, read [CONTRIBUTING.md](CONTRIBUTING.md).

LunaSea Web is available under the [GNU General Public License v3.0](LICENSE.md).
