# Build
FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS build

ARG FLUTTER_VERSION=3.41.9
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:$PATH"
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN git clone --branch "$FLUTTER_VERSION" --depth 1 https://github.com/flutter/flutter.git /usr/local/flutter
RUN flutter --version

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
RUN dart pub global activate spider

COPY analysis_options.yaml build.yaml environment_config.yaml spider.yaml ./
COPY assets ./assets
COPY lib ./lib
COPY localization ./localization
COPY web ./web
RUN dart run environment_config:generate
RUN dart pub global run spider build
RUN dart run build_runner build
RUN flutter build web

# Gateway
FROM --platform=$BUILDPLATFORM golang:1.26.3-alpine3.23 AS gateway

ARG TARGETOS
ARG TARGETARCH

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY server ./server
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-amd64} \
  go build -trimpath -ldflags="-s -w" -o /out/lunasea-gateway ./server
RUN mkdir -p /runtime/data

# Runtime
FROM gcr.io/distroless/static-debian12:nonroot

ENV LUNASEA_ADDR=:8080
ENV LUNASEA_DATA_DIR=/data
ENV LUNASEA_STATIC_DIR=/usr/share/lunasea/web

VOLUME ["/data"]
EXPOSE 8080

COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=gateway --chown=65532:65532 /runtime/data /data
COPY --from=build --chown=65532:65532 /app/build/web /usr/share/lunasea/web
COPY --from=gateway --chown=65532:65532 /out/lunasea-gateway /usr/local/bin/lunasea-gateway

USER 65532:65532
ENTRYPOINT ["/usr/local/bin/lunasea-gateway"]
