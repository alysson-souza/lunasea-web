package main

import (
	"context"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	_ "modernc.org/sqlite"
)

func newTestApp(t *testing.T) *app {
	t.Helper()
	store, err := openStore(":memory:")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = store.close() })
	return &app{
		store:     store,
		proxy:     newProxyHandler(store),
		staticDir: t.TempDir(),
	}
}

func TestStoreSupportsMultipleServiceInstancesPerProfile(t *testing.T) {
	app := newTestApp(t)
	ctx := context.Background()

	for _, cfg := range []serviceConfig{
		{Service: serviceRadarr, Profile: "default", InstanceID: "nas-films", DisplayName: "NAS Films", Enabled: true, UpstreamURL: "https://nas.example/radarr"},
		{Service: serviceRadarr, Profile: "default", InstanceID: "seedbox-films", DisplayName: "Seedbox Films", Enabled: true, UpstreamURL: "https://seedbox.example/radarr"},
	} {
		if err := app.store.putService(ctx, cfg); err != nil {
			t.Fatal(err)
		}
	}

	nas, err := app.store.getService(ctx, serviceRadarr, "default", "nas-films")
	if err != nil {
		t.Fatal(err)
	}
	seedbox, err := app.store.getService(ctx, serviceRadarr, "default", "seedbox-films")
	if err != nil {
		t.Fatal(err)
	}
	if nas.UpstreamURL == seedbox.UpstreamURL {
		t.Fatalf("expected distinct upstreams, got %q", nas.UpstreamURL)
	}
}

func TestDeleteServiceRemovesOnlyRequestedInstance(t *testing.T) {
	app := newTestApp(t)
	ctx := context.Background()

	for _, cfg := range []serviceConfig{
		{Service: serviceSonarr, Profile: "default", InstanceID: "nas-anime", DisplayName: "NAS Anime", Enabled: true, UpstreamURL: "https://nas.example/sonarr"},
		{Service: serviceSonarr, Profile: "default", InstanceID: "seedbox-anime", DisplayName: "Seedbox Anime", Enabled: true, UpstreamURL: "https://seedbox.example/sonarr"},
	} {
		if err := app.store.putService(ctx, cfg); err != nil {
			t.Fatal(err)
		}
	}

	if err := app.store.deleteService(ctx, serviceSonarr, "default", "nas-anime"); err != nil {
		t.Fatal(err)
	}
	if _, err := app.store.getService(ctx, serviceSonarr, "default", "nas-anime"); !errors.Is(err, errNotFound) {
		t.Fatalf("deleted instance err = %v", err)
	}
	if _, err := app.store.getService(ctx, serviceSonarr, "default", "seedbox-anime"); err != nil {
		t.Fatalf("remaining instance err = %v", err)
	}
}

func TestStoreRetrievesDisabledServiceInstance(t *testing.T) {
	app := newTestApp(t)
	ctx := context.Background()

	if err := app.store.putService(ctx, serviceConfig{
		Service:     serviceRadarr,
		Profile:     "default",
		InstanceID:  "disabled-films",
		DisplayName: "Disabled Films",
		Enabled:     false,
		UpstreamURL: "https://disabled.example/radarr",
	}); err != nil {
		t.Fatal(err)
	}

	cfg, err := app.store.getService(ctx, serviceRadarr, "default", "disabled-films")
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Enabled {
		t.Fatal("expected disabled instance to remain disabled")
	}
	if cfg.UpstreamURL != "https://disabled.example/radarr" {
		t.Fatalf("upstream = %q", cfg.UpstreamURL)
	}
}

func TestCreateServiceInstanceDefaultsAndReturnsID(t *testing.T) {
	app := newTestApp(t)
	ctx := context.Background()

	rec := httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(
		http.MethodPost,
		"/_lunasea/api/profiles/default/services/radarr/instances",
		strings.NewReader(`{"upstreamUrl":"https://new.example/radarr","apiKey":"new-key"}`),
	))
	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}

	var body serviceResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.Enabled {
		t.Fatalf("response enabled = true, want disabled by default")
	}
	if body.InstanceID == "" {
		t.Fatalf("id = %q", body.InstanceID)
	}
	if body.DisplayName != serviceRadarr || body.ConnectionMode != "gateway" {
		t.Fatalf("defaults = %#v", body)
	}
	if strings.Contains(rec.Body.String(), "new-key") || !body.HasAPIKey {
		t.Fatalf("response did not redact api key: %s", rec.Body.String())
	}

	cfg, err := app.store.getService(ctx, serviceRadarr, "default", body.InstanceID)
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Enabled || cfg.DisplayName != serviceRadarr || cfg.ConnectionMode != "gateway" {
		t.Fatalf("stored defaults = %#v", cfg)
	}
	if cfg.UpstreamURL != "https://new.example/radarr" || cfg.APIKey != "new-key" {
		t.Fatalf("stored service = %#v", cfg)
	}
}

func TestPatchServiceInstanceUpdatesExistingConfig(t *testing.T) {
	app := newTestApp(t)
	ctx := context.Background()

	if err := app.store.putService(ctx, serviceConfig{
		Service:     serviceRadarr,
		Profile:     "default",
		InstanceID:  "nas-films",
		DisplayName: "NAS Films",
		Enabled:     true,
		UpstreamURL: "https://old.example/radarr",
		APIKey:      "old-key",
	}); err != nil {
		t.Fatal(err)
	}

	rec := httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(
		http.MethodPatch,
		"/_lunasea/api/profiles/default/services/radarr/instances/nas-films",
		strings.NewReader(`{"displayName":"NAS Movies","upstreamUrl":"https://new.example/radarr","apiKey":"new-key"}`),
	))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	if strings.Contains(rec.Body.String(), "new-key") {
		t.Fatalf("patch response leaked api key: %s", rec.Body.String())
	}

	cfg, err := app.store.getService(ctx, serviceRadarr, "default", "nas-films")
	if err != nil {
		t.Fatal(err)
	}
	if cfg.DisplayName != "NAS Movies" || cfg.UpstreamURL != "https://new.example/radarr" || cfg.APIKey != "new-key" {
		t.Fatalf("stored service = %#v", cfg)
	}
}

func TestPatchServiceInstancePreservesRedactedSecretsAndHeaders(t *testing.T) {
	app := newTestApp(t)
	ctx := context.Background()

	if err := app.store.putService(ctx, serviceConfig{
		Service:     serviceRadarr,
		Profile:     "default",
		InstanceID:  "nas-films",
		DisplayName: "NAS Films",
		Enabled:     true,
		UpstreamURL: "https://old.example/radarr",
		APIKey:      "old-key",
		Username:    "old-user",
		Password:    "old-pass",
		Headers:     map[string]string{"X-Custom": "yes"},
	}); err != nil {
		t.Fatal(err)
	}

	rec := httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(
		http.MethodPatch,
		"/_lunasea/api/profiles/default/services/radarr/instances/nas-films",
		strings.NewReader(`{"displayName":"NAS Movies","apiKey":"","username":"","password":"","headers":{}}`),
	))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}

	cfg, err := app.store.getService(ctx, serviceRadarr, "default", "nas-films")
	if err != nil {
		t.Fatal(err)
	}
	if cfg.DisplayName != "NAS Movies" {
		t.Fatalf("display name = %q", cfg.DisplayName)
	}
	if cfg.APIKey != "old-key" || cfg.Username != "old-user" || cfg.Password != "old-pass" {
		t.Fatalf("secrets were not preserved: %#v", cfg)
	}
	if cfg.Headers["X-Custom"] != "yes" || len(cfg.Headers) != 1 {
		t.Fatalf("headers were not preserved: %#v", cfg.Headers)
	}
}

func TestPatchServiceInstanceAllowsEmptyUpstreamForIncompleteInstance(t *testing.T) {
	app := newTestApp(t)
	ctx := context.Background()

	if err := app.store.putService(ctx, serviceConfig{
		Service:     serviceRadarr,
		Profile:     "default",
		InstanceID:  "incomplete",
		DisplayName: "Incomplete",
		Enabled:     false,
		UpstreamURL: "",
	}); err != nil {
		t.Fatal(err)
	}

	rec := httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(
		http.MethodPatch,
		"/_lunasea/api/profiles/default/services/radarr/instances/incomplete",
		strings.NewReader(`{"displayName":"Draft","enabled":false,"sortOrder":4,"preferences":{"rootFolderId":10},"upstreamUrl":""}`),
	))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}

	cfg, err := app.store.getService(ctx, serviceRadarr, "default", "incomplete")
	if err != nil {
		t.Fatal(err)
	}
	if cfg.UpstreamURL != "" || cfg.DisplayName != "Draft" || cfg.Enabled || cfg.SortOrder != 4 {
		t.Fatalf("stored service = %#v", cfg)
	}
	if cfg.Preferences["rootFolderId"] != float64(10) {
		t.Fatalf("preferences = %#v", cfg.Preferences)
	}
}

func TestPatchServiceInstanceMissingReturnsNotFound(t *testing.T) {
	app := newTestApp(t)
	rec := httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(
		http.MethodPatch,
		"/_lunasea/api/profiles/default/services/radarr/instances/missing",
		strings.NewReader(`{"displayName":"Missing","upstreamUrl":"https://new.example/radarr"}`),
	))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
}

func TestStoreMigratesLegacyServiceConnectionsToDefaultInstances(t *testing.T) {
	path := t.TempDir() + "/state.db"
	db, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC().Format(time.RFC3339)
	_, err = db.Exec(`
CREATE TABLE schema_migrations (
  version INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  applied_at TEXT NOT NULL
) STRICT;
CREATE TABLE profiles (
  id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
) STRICT;
INSERT INTO profiles (id, display_name, sort_order, created_at, updated_at) VALUES ('default', 'default', 0, ?, ?);
CREATE TABLE service_connections (
  profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  service TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0, 1)),
  upstream_url TEXT NOT NULL DEFAULT '',
  api_key TEXT NOT NULL DEFAULT '',
  username TEXT NOT NULL DEFAULT '',
  password TEXT NOT NULL DEFAULT '',
  headers_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (profile_id, service)
) STRICT;
INSERT INTO service_connections (profile_id, service, enabled, upstream_url, api_key, username, password, headers_json, created_at, updated_at)
VALUES ('default', 'radarr', 1, 'https://legacy.example/radarr', 'legacy-key', 'user', 'pass', '{"X-Legacy":"yes"}', ?, ?);`, now, now, now, now)
	if closeErr := db.Close(); closeErr != nil && err == nil {
		err = closeErr
	}
	if err != nil {
		t.Fatal(err)
	}

	store, err := openStore(path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = store.close() })

	cfg, err := store.getService(context.Background(), serviceRadarr, "default", defaultServiceInstanceID)
	if err != nil {
		t.Fatal(err)
	}
	if cfg.InstanceID != defaultServiceInstanceID || cfg.DisplayName != serviceRadarr || cfg.ConnectionMode != "gateway" {
		t.Fatalf("migrated identity = %#v", cfg)
	}
	if cfg.UpstreamURL != "https://legacy.example/radarr" || cfg.APIKey != "legacy-key" || cfg.Headers["X-Legacy"] != "yes" {
		t.Fatalf("migrated config = %#v", cfg)
	}

	var count int
	if err := store.db.QueryRowContext(context.Background(), `SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'service_connections';`).Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 0 {
		t.Fatal("expected legacy service_connections table to be dropped")
	}
}

func TestStateBootstrapsDefaultBackendState(t *testing.T) {
	app := newTestApp(t)
	rec := httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/_lunasea/api/state", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}

	var state map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &state); err != nil {
		t.Fatal(err)
	}
	if state["gateway"] != true {
		t.Fatalf("gateway = %#v", state["gateway"])
	}
	if activeProfile := state["activeProfile"]; activeProfile != "default" {
		t.Fatalf("activeProfile = %#v", activeProfile)
	}
	if profiles := state["profiles"].([]any); len(profiles) != 1 {
		t.Fatalf("profiles = %#v", profiles)
	}
	if instances := state["serviceInstances"].([]any); len(instances) != 0 {
		t.Fatalf("serviceInstances = %#v", instances)
	}
	if _, ok := state["serviceConnections"]; ok {
		t.Fatalf("legacy serviceConnections present: %#v", state["serviceConnections"])
	}
	if prefs := state["preferences"].(map[string]any); prefs["activeProfile"] != "default" {
		t.Fatalf("preferences = %#v", prefs)
	}
	if modules := state["modulePreferences"].(map[string]any); len(modules) == 0 {
		t.Fatalf("modulePreferences = %#v", modules)
	}
}

func TestStateListsServiceInstances(t *testing.T) {
	app := newTestApp(t)
	ctx := context.Background()
	for _, cfg := range []serviceConfig{
		{Service: serviceSonarr, Profile: "default", InstanceID: "nas-anime", DisplayName: "NAS Anime", Enabled: true, UpstreamURL: "https://nas.example/sonarr"},
		{Service: serviceSonarr, Profile: "default", InstanceID: "seedbox-anime", DisplayName: "Seedbox Anime", Enabled: true, UpstreamURL: "https://seedbox.example/sonarr"},
	} {
		if err := app.store.putService(ctx, cfg); err != nil {
			t.Fatal(err)
		}
	}

	rec := httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/_lunasea/api/state", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
	var body struct {
		ServiceInstances   []serviceResponse `json:"serviceInstances"`
		ServiceConnections []serviceResponse `json:"serviceConnections"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if len(body.ServiceInstances) != 2 {
		t.Fatalf("serviceInstances len = %d", len(body.ServiceInstances))
	}
	if len(body.ServiceConnections) != 0 {
		t.Fatalf("legacy serviceConnections should be absent, got %d", len(body.ServiceConnections))
	}
}

func TestStateIncludesDisabledAndIncompleteServiceInstances(t *testing.T) {
	app := newTestApp(t)
	ctx := context.Background()
	for _, cfg := range []serviceConfig{
		{Service: serviceRadarr, Profile: "default", InstanceID: "enabled", DisplayName: "Enabled", Enabled: true, UpstreamURL: "https://enabled.example/radarr"},
		{Service: serviceRadarr, Profile: "default", InstanceID: "disabled", DisplayName: "Disabled", Enabled: false, UpstreamURL: "https://disabled.example/radarr"},
		{Service: serviceRadarr, Profile: "default", InstanceID: "incomplete", DisplayName: "Incomplete", Enabled: true, UpstreamURL: ""},
	} {
		if err := app.store.putService(ctx, cfg); err != nil {
			t.Fatal(err)
		}
	}

	rec := httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/_lunasea/api/state", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
	var body struct {
		ServiceInstances []serviceResponse `json:"serviceInstances"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	seen := map[string]bool{}
	for _, instance := range body.ServiceInstances {
		seen[instance.InstanceID] = true
	}
	for _, id := range []string{"enabled", "disabled", "incomplete"} {
		if !seen[id] {
			t.Fatalf("missing %s from state: %#v", id, body.ServiceInstances)
		}
	}
}

func TestServiceConfigRedactsSecrets(t *testing.T) {
	app := newTestApp(t)
	cfg := serviceConfig{
		Service:     serviceRadarr,
		Profile:     "default",
		InstanceID:  defaultServiceInstanceID,
		Enabled:     true,
		UpstreamURL: "https://radarr.example",
		APIKey:      "secret",
		Username:    "user",
		Password:    "pass",
	}
	if err := app.store.putService(context.Background(), cfg); err != nil {
		t.Fatal(err)
	}

	req := httptest.NewRequest(http.MethodGet, "/_lunasea/api/services", nil)
	rec := httptest.NewRecorder()
	app.routes().ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	body := rec.Body.String()
	if strings.Contains(body, "secret") || strings.Contains(body, "pass") {
		t.Fatalf("response leaked secret: %s", body)
	}
	if !strings.Contains(body, `"hasApiKey":true`) {
		t.Fatalf("response did not report redacted API key: %s", body)
	}
}

func TestValidateInstanceID(t *testing.T) {
	for _, value := range []string{"default", "nas-films", "seedbox_anime", "ABC123"} {
		if err := validateInstanceID(value); err != nil {
			t.Fatalf("validateInstanceID(%q) returned %v", value, err)
		}
	}

	for _, value := range []string{"", "has space", "name/with/slash", "name?query"} {
		if err := validateInstanceID(value); err == nil {
			t.Fatalf("validateInstanceID(%q) returned nil", value)
		}
	}
}

func TestServiceResponseIncludesInstanceProxyPath(t *testing.T) {
	cfg := serviceConfig{
		Service:     serviceRadarr,
		Profile:     "default",
		InstanceID:  "nas-films",
		DisplayName: "NAS Films",
		Enabled:     true,
		UpstreamURL: "https://radarr.example",
		APIKey:      "secret",
	}

	got := cfg.redacted()
	if got.InstanceID != "nas-films" {
		t.Fatalf("instance = %q", got.InstanceID)
	}
	if got.DisplayName != "NAS Films" {
		t.Fatalf("displayName = %q", got.DisplayName)
	}
	if got.ProxyPath != "/_lunasea/proxy/radarr/default/nas-films/" {
		t.Fatalf("proxyPath = %q", got.ProxyPath)
	}
	if !got.HasAPIKey {
		t.Fatal("expected API key to be redacted as present")
	}
}

func TestIndexerStateRedactsSecretsAndProxyUsesBackendCredentials(t *testing.T) {
	var seenAPIKey string
	var seenHeader string
	var seenDownloadAPIKey string
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seenHeader = r.Header.Get("X-Custom")
		switch r.URL.Query().Get("t") {
		case "search":
			seenAPIKey = r.URL.Query().Get("apikey")
			w.Header().Set("Content-Type", "application/xml")
			_, _ = w.Write([]byte(`<rss><channel><item><title>Release</title><link>` +
				upstreamDownloadURL(r, "secret-indexer-key") +
				`</link></item></channel></rss>`))
		case "get":
			seenDownloadAPIKey = r.URL.Query().Get("apikey")
			_, _ = w.Write([]byte("nzb"))
		default:
			t.Fatalf("unexpected upstream request: %s", r.URL.String())
		}
	}))
	defer upstream.Close()

	app := newTestApp(t)
	rec := httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(
		http.MethodPost,
		"/_lunasea/api/indexers",
		strings.NewReader(`{"displayName":"Indexer","host":"`+upstream.URL+`","apiKey":"secret-indexer-key","headers":{"X-Custom":"stored-header"}}`),
	))
	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	if strings.Contains(rec.Body.String(), "secret-indexer-key") || strings.Contains(rec.Body.String(), "stored-header") {
		t.Fatalf("create response leaked secret: %s", rec.Body.String())
	}
	var created map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &created); err != nil {
		t.Fatal(err)
	}
	id := int(created["id"].(float64))

	rec = httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/_lunasea/api/state", nil))
	if strings.Contains(rec.Body.String(), "secret-indexer-key") || strings.Contains(rec.Body.String(), "stored-header") {
		t.Fatalf("state response leaked secret: %s", rec.Body.String())
	}

	req := httptest.NewRequest(http.MethodGet, "/_lunasea/api/indexers/1/proxy?t=search", nil)
	req.Host = "lunasea.local"
	req.Header.Set("X-Forwarded-Proto", "https")
	rec = httptest.NewRecorder()
	app.routes().ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	body := rec.Body.String()
	if seenAPIKey != "secret-indexer-key" {
		t.Fatalf("upstream apikey = %q", seenAPIKey)
	}
	if seenHeader != "stored-header" {
		t.Fatalf("upstream header = %q", seenHeader)
	}
	if strings.Contains(body, "secret-indexer-key") {
		t.Fatalf("proxy response leaked secret: %s", body)
	}
	if !strings.Contains(body, "https://lunasea.local/_lunasea/api/indexers/1/download") {
		t.Fatalf("proxy response did not rewrite download link: %s", body)
	}

	link := extractXMLLink(t, body)
	downloadURL, err := url.Parse(strings.ReplaceAll(link, "&amp;", "&"))
	if err != nil {
		t.Fatal(err)
	}
	rec = httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, downloadURL.RequestURI(), nil))
	if rec.Code != http.StatusOK || rec.Body.String() != "nzb" {
		t.Fatalf("download status = %d, body = %s", rec.Code, rec.Body.String())
	}
	if seenDownloadAPIKey != "secret-indexer-key" {
		t.Fatalf("download apikey = %q", seenDownloadAPIKey)
	}
	if id != 1 {
		t.Fatalf("id = %d", id)
	}
}

func TestPatchIndexerPreservesStoredSecretsWhenRedactedFieldsAreOmitted(t *testing.T) {
	app := newTestApp(t)
	created, err := app.store.createIndexer(context.Background(), indexerRecord{
		DisplayName: "Indexer",
		Host:        "https://indexer.example",
		APIKey:      "secret",
		Headers:     map[string]string{"X-Custom": "stored"},
	})
	if err != nil {
		t.Fatal(err)
	}

	rec := httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(
		http.MethodPatch,
		"/_lunasea/api/indexers/1",
		strings.NewReader(`{"displayName":"Renamed","host":"https://indexer.example"}`),
	))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	if strings.Contains(rec.Body.String(), "secret") || strings.Contains(rec.Body.String(), "stored") {
		t.Fatalf("patch response leaked secret: %s", rec.Body.String())
	}

	got, err := app.store.getIndexer(context.Background(), created.ID, true)
	if err != nil {
		t.Fatal(err)
	}
	if got.DisplayName != "Renamed" || got.APIKey != "secret" || got.Headers["X-Custom"] != "stored" {
		t.Fatalf("indexer = %#v", got)
	}
}

func upstreamDownloadURL(r *http.Request, apiKey string) string {
	u := *r.URL
	u.Path = "/api"
	query := u.Query()
	query.Set("t", "get")
	query.Set("id", "123")
	query.Set("apikey", apiKey)
	u.RawQuery = query.Encode()
	u.Scheme = "http"
	u.Host = r.Host
	return u.String()
}

func extractXMLLink(t *testing.T, body string) string {
	t.Helper()
	start := strings.Index(body, "<link>")
	end := strings.Index(body, "</link>")
	if start < 0 || end < 0 || end < start {
		t.Fatalf("missing link in %s", body)
	}
	return body[start+len("<link>") : end]
}

func TestProxyInjectsArrAPIKeyWithoutRestart(t *testing.T) {
	var seenKeys []string
	var seenPath string
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seenKeys = append(seenKeys, r.Header.Get("X-Api-Key"))
		seenPath = r.URL.Path
		_, _ = w.Write([]byte(`{"ok":true}`))
	}))
	defer upstream.Close()

	app := newTestApp(t)
	if err := app.store.putService(context.Background(), serviceConfig{
		Service:     serviceRadarr,
		Profile:     "default",
		InstanceID:  defaultServiceInstanceID,
		Enabled:     true,
		UpstreamURL: upstream.URL,
		APIKey:      "first",
	}); err != nil {
		t.Fatal(err)
	}

	router := app.routes()
	router.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(
		http.MethodGet,
		"/_lunasea/proxy/radarr/default/default/api/v3/system/status",
		nil,
	))

	if err := app.store.putService(context.Background(), serviceConfig{
		Service:     serviceRadarr,
		Profile:     "default",
		InstanceID:  defaultServiceInstanceID,
		Enabled:     true,
		UpstreamURL: upstream.URL,
		APIKey:      "second",
	}); err != nil {
		t.Fatal(err)
	}
	router.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(
		http.MethodGet,
		"/_lunasea/proxy/radarr/default/default/api/v3/system/status",
		nil,
	))

	if got := strings.Join(seenKeys, ","); got != "first,second" {
		t.Fatalf("seen API keys = %q", got)
	}
	if seenPath != "/api/v3/system/status" {
		t.Fatalf("upstream path = %q", seenPath)
	}
}

func TestProxyUsesServiceInstanceFromPath(t *testing.T) {
	ctx := context.Background()
	var nasHits int
	var seedboxHits int
	nas := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		nasHits++
		_, _ = w.Write([]byte(`{"source":"nas"}`))
	}))
	defer nas.Close()
	seedbox := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seedboxHits++
		_, _ = w.Write([]byte(`{"source":"seedbox"}`))
	}))
	defer seedbox.Close()

	app := newTestApp(t)
	for _, cfg := range []serviceConfig{
		{Service: serviceRadarr, Profile: "default", InstanceID: "nas-films", DisplayName: "NAS Films", Enabled: true, UpstreamURL: nas.URL},
		{Service: serviceRadarr, Profile: "default", InstanceID: "seedbox-films", DisplayName: "Seedbox Films", Enabled: true, UpstreamURL: seedbox.URL},
	} {
		if err := app.store.putService(ctx, cfg); err != nil {
			t.Fatal(err)
		}
	}

	for _, path := range []string{
		"/_lunasea/proxy/radarr/default/nas-films/api/v3/system/status",
		"/_lunasea/proxy/radarr/default/seedbox-films/api/v3/system/status",
	} {
		rec := httptest.NewRecorder()
		app.routes().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
		if rec.Code != http.StatusOK {
			t.Fatalf("%s status = %d body = %s", path, rec.Code, rec.Body.String())
		}
	}
	if nasHits != 1 || seedboxHits != 1 {
		t.Fatalf("hits nas=%d seedbox=%d", nasHits, seedboxHits)
	}
}

func TestProxyReplacesBrowserArrAPIKeyWithServerHeader(t *testing.T) {
	var seenHeader string
	var seenQuery string
	var seenAuthorization string
	var seenCookie string
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seenHeader = r.Header.Get("X-Api-Key")
		seenQuery = r.URL.RawQuery
		seenAuthorization = r.Header.Get("Authorization")
		seenCookie = r.Header.Get("Cookie")
		_, _ = w.Write([]byte(`{"ok":true}`))
	}))
	defer upstream.Close()

	app := newTestApp(t)
	if err := app.store.putService(context.Background(), serviceConfig{
		Service:     serviceRadarr,
		Profile:     "default",
		InstanceID:  defaultServiceInstanceID,
		Enabled:     true,
		UpstreamURL: upstream.URL,
		APIKey:      "server-secret",
	}); err != nil {
		t.Fatal(err)
	}

	req := httptest.NewRequest(
		http.MethodGet,
		"/_lunasea/proxy/radarr/default/default/api/v3/system/status?apikey=browser-secret&page=1",
		nil,
	)
	req.Header.Set("Authorization", "Bearer browser-token")
	req.Header.Set("Cookie", "gateway_session=secret")
	rec := httptest.NewRecorder()
	app.routes().ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	if seenHeader != "server-secret" {
		t.Fatalf("X-Api-Key = %q", seenHeader)
	}
	if seenQuery != "page=1" {
		t.Fatalf("query = %q", seenQuery)
	}
	if seenAuthorization != "" {
		t.Fatalf("authorization header leaked: %q", seenAuthorization)
	}
	if seenCookie != "" {
		t.Fatalf("cookie header leaked: %q", seenCookie)
	}
}

func TestProxyInjectsNZBGetBasicAuth(t *testing.T) {
	var auth string
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		auth = r.Header.Get("Authorization")
		_, _ = w.Write([]byte(`{"result":"ok"}`))
	}))
	defer upstream.Close()

	app := newTestApp(t)
	if err := app.store.putService(context.Background(), serviceConfig{
		Service:     serviceNZBGet,
		Profile:     "default",
		InstanceID:  defaultServiceInstanceID,
		Enabled:     true,
		UpstreamURL: upstream.URL,
		Username:    "alice",
		Password:    "secret",
	}); err != nil {
		t.Fatal(err)
	}

	rec := httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(
		http.MethodPost,
		"/_lunasea/proxy/nzbget/default/default/jsonrpc",
		strings.NewReader(`{}`),
	))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}

	expected := "Basic " + base64.StdEncoding.EncodeToString([]byte("alice:secret"))
	if auth != expected {
		t.Fatalf("authorization = %q, expected %q", auth, expected)
	}
}

func TestDeleteServiceInstanceMakesOnlyThatProxyUnconfigured(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"ok":true}`))
	}))
	defer upstream.Close()

	app := newTestApp(t)
	for _, cfg := range []serviceConfig{{
		Service:     serviceSonarr,
		Profile:     "default",
		InstanceID:  "nas-anime",
		DisplayName: "NAS Anime",
		Enabled:     true,
		UpstreamURL: upstream.URL,
		APIKey:      "secret",
	}, {
		Service:     serviceSonarr,
		Profile:     "default",
		InstanceID:  "seedbox-anime",
		DisplayName: "Seedbox Anime",
		Enabled:     true,
		UpstreamURL: upstream.URL,
		APIKey:      "secret",
	}} {
		if err := app.store.putService(context.Background(), cfg); err != nil {
			t.Fatal(err)
		}
	}

	rec := httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(
		http.MethodDelete,
		"/_lunasea/api/profiles/default/services/sonarr/instances/nas-anime",
		nil,
	))
	if rec.Code != http.StatusNoContent {
		t.Fatalf("delete status = %d, body = %s", rec.Code, rec.Body.String())
	}

	rec = httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(
		http.MethodGet,
		"/_lunasea/proxy/sonarr/default/nas-anime/api/v3/system/status",
		nil,
	))
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	var body map[string]map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body["error"]["code"] != "unconfigured" {
		t.Fatalf("error = %#v", body)
	}

	rec = httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(
		http.MethodGet,
		"/_lunasea/proxy/sonarr/default/seedbox-anime/api/v3/system/status",
		nil,
	))
	if rec.Code != http.StatusOK {
		t.Fatalf("remaining proxy status = %d, body = %s", rec.Code, rec.Body.String())
	}
}

func TestAppShellIsServedWithoutCache(t *testing.T) {
	app := newTestApp(t)
	for _, testCase := range []struct {
		name string
		path string
	}{
		{name: "index.html", path: "/"},
		{name: "flutter_bootstrap.js", path: "/flutter_bootstrap.js"},
		{name: "flutter_service_worker.js", path: "/flutter_service_worker.js"},
		{name: "main.dart.js", path: "/main.dart.js"},
	} {
		if err := os.WriteFile(app.staticDir+"/"+testCase.name, []byte("ok"), 0o644); err != nil {
			t.Fatal(err)
		}

		rec := httptest.NewRecorder()
		app.routes().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, testCase.path, nil))
		if rec.Code != http.StatusOK {
			t.Fatalf("%s status = %d", testCase.name, rec.Code)
		}
		if got := rec.Header().Get("Cache-Control"); got != "no-store" {
			t.Fatalf("%s Cache-Control = %q", testCase.name, got)
		}
	}
}

func TestServiceTestUsesServiceSpecificQuery(t *testing.T) {
	for _, tt := range []struct {
		service  string
		wantPath string
		wantRaw  string
	}{
		{
			service:  serviceSABnzbd,
			wantPath: "/api",
			wantRaw:  "apikey=secret&mode=version&output=json",
		},
		{
			service:  serviceTautulli,
			wantPath: "/api/v2",
			wantRaw:  "apikey=secret&cmd=status",
		},
	} {
		t.Run(tt.service, func(t *testing.T) {
			var seenPath string
			var seenRaw string
			upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				seenPath = r.URL.Path
				seenRaw = r.URL.RawQuery
				_, _ = w.Write([]byte(`{"ok":true}`))
			}))
			defer upstream.Close()

			app := newTestApp(t)
			if err := app.store.putService(context.Background(), serviceConfig{
				Service:     tt.service,
				Profile:     "default",
				InstanceID:  defaultServiceInstanceID,
				Enabled:     true,
				UpstreamURL: upstream.URL,
				APIKey:      "secret",
			}); err != nil {
				t.Fatal(err)
			}

			rec := httptest.NewRecorder()
			app.routes().ServeHTTP(rec, httptest.NewRequest(
				http.MethodPost,
				"/_lunasea/api/profiles/default/services/"+tt.service+"/instances/default/test",
				nil,
			))
			if rec.Code != http.StatusOK {
				t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
			}
			if seenPath != tt.wantPath {
				t.Fatalf("path = %q", seenPath)
			}
			if seenRaw != tt.wantRaw {
				t.Fatalf("query = %q", seenRaw)
			}
		})
	}
}

func TestServiceInstanceTestUsesRequestedInstance(t *testing.T) {
	var nasHits int
	var seedboxHits int
	nas := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		nasHits++
		_, _ = w.Write([]byte(`{"version":"nas"}`))
	}))
	defer nas.Close()
	seedbox := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seedboxHits++
		_, _ = w.Write([]byte(`{"version":"seedbox"}`))
	}))
	defer seedbox.Close()

	app := newTestApp(t)
	for _, cfg := range []serviceConfig{
		{Service: serviceRadarr, Profile: "default", InstanceID: "nas-films", DisplayName: "NAS Films", Enabled: true, UpstreamURL: nas.URL},
		{Service: serviceRadarr, Profile: "default", InstanceID: "seedbox-films", DisplayName: "Seedbox Films", Enabled: true, UpstreamURL: seedbox.URL},
	} {
		if err := app.store.putService(context.Background(), cfg); err != nil {
			t.Fatal(err)
		}
	}

	rec := httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(
		http.MethodPost,
		"/_lunasea/api/profiles/default/services/radarr/instances/seedbox-films/test",
		nil,
	))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	if nasHits != 0 || seedboxHits != 1 {
		t.Fatalf("hits nas=%d seedbox=%d", nasHits, seedboxHits)
	}
}

func TestBuildUpstreamURLKeepsConfiguredSubpath(t *testing.T) {
	got, err := buildUpstreamURL("https://media.example/radarr", "api/v3/system/status", "page=1")
	if err != nil {
		t.Fatal(err)
	}
	if got.String() != "https://media.example/radarr/api/v3/system/status?page=1" {
		t.Fatalf("url = %s", got.String())
	}
}
