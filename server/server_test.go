package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
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
	if connections := state["serviceConnections"].([]any); len(connections) != 0 {
		t.Fatalf("serviceConnections = %#v", connections)
	}
	if prefs := state["preferences"].(map[string]any); prefs["activeProfile"] != "default" {
		t.Fatalf("preferences = %#v", prefs)
	}
	if modules := state["modulePreferences"].(map[string]any); len(modules) == 0 {
		t.Fatalf("modulePreferences = %#v", modules)
	}
}

func TestServiceConfigRedactsSecrets(t *testing.T) {
	app := newTestApp(t)
	cfg := serviceConfig{
		Service:     serviceRadarr,
		Profile:     "default",
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
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seenKeys = append(seenKeys, r.Header.Get("X-Api-Key"))
		_, _ = w.Write([]byte(`{"ok":true}`))
	}))
	defer upstream.Close()

	app := newTestApp(t)
	if err := app.store.putService(context.Background(), serviceConfig{
		Service:     serviceRadarr,
		Profile:     "default",
		UpstreamURL: upstream.URL,
		APIKey:      "first",
	}); err != nil {
		t.Fatal(err)
	}

	router := app.routes()
	router.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(
		http.MethodGet,
		"/_lunasea/proxy/radarr/default/api/v3/system/status",
		nil,
	))

	if err := app.store.putService(context.Background(), serviceConfig{
		Service:     serviceRadarr,
		Profile:     "default",
		UpstreamURL: upstream.URL,
		APIKey:      "second",
	}); err != nil {
		t.Fatal(err)
	}
	router.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(
		http.MethodGet,
		"/_lunasea/proxy/radarr/default/api/v3/system/status",
		nil,
	))

	if got := strings.Join(seenKeys, ","); got != "first,second" {
		t.Fatalf("seen API keys = %q", got)
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
		UpstreamURL: upstream.URL,
		APIKey:      "server-secret",
	}); err != nil {
		t.Fatal(err)
	}

	req := httptest.NewRequest(
		http.MethodGet,
		"/_lunasea/proxy/radarr/default/api/v3/system/status?apikey=browser-secret&page=1",
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
		UpstreamURL: upstream.URL,
		Username:    "alice",
		Password:    "secret",
	}); err != nil {
		t.Fatal(err)
	}

	rec := httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(
		http.MethodPost,
		"/_lunasea/proxy/nzbget/default/jsonrpc",
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

func TestDeleteServiceMakesProxyUnconfigured(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"ok":true}`))
	}))
	defer upstream.Close()

	app := newTestApp(t)
	if err := app.store.putService(context.Background(), serviceConfig{
		Service:     serviceSonarr,
		Profile:     "default",
		UpstreamURL: upstream.URL,
		APIKey:      "secret",
	}); err != nil {
		t.Fatal(err)
	}
	if err := app.store.deleteService(context.Background(), serviceSonarr, "default"); err != nil {
		t.Fatal(err)
	}

	rec := httptest.NewRecorder()
	app.routes().ServeHTTP(rec, httptest.NewRequest(
		http.MethodGet,
		"/_lunasea/proxy/sonarr/default/api/v3/system/status",
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
				UpstreamURL: upstream.URL,
				APIKey:      "secret",
			}); err != nil {
				t.Fatal(err)
			}

			rec := httptest.NewRecorder()
			app.routes().ServeHTTP(rec, httptest.NewRequest(
				http.MethodPost,
				"/_lunasea/api/services/"+tt.service+"/default/test",
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

func TestBuildUpstreamURLKeepsConfiguredSubpath(t *testing.T) {
	got, err := buildUpstreamURL("https://media.example/radarr", "api/v3/system/status", "page=1")
	if err != nil {
		t.Fatal(err)
	}
	if got.String() != "https://media.example/radarr/api/v3/system/status?page=1" {
		t.Fatalf("url = %s", got.String())
	}
}
