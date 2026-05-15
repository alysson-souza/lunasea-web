package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type app struct {
	store     *store
	proxy     *proxyHandler
	staticDir string
}

func main() {
	dataDir := env("LUNASEA_DATA_DIR", "/data")
	staticDir := env("LUNASEA_STATIC_DIR", "/usr/share/lunasea/web")
	addr := env("LUNASEA_ADDR", ":8080")

	if err := os.MkdirAll(dataDir, 0o755); err != nil {
		log.Fatal(err)
	}
	store, err := openStore(filepath.Join(dataDir, "lunasea.db"))
	if err != nil {
		log.Fatal(err)
	}
	defer store.close()

	app := &app{
		store:     store,
		proxy:     newProxyHandler(store),
		staticDir: staticDir,
	}

	server := &http.Server{
		Addr:              addr,
		Handler:           app.routes(),
		ReadHeaderTimeout: 10 * time.Second,
	}
	log.Printf("LunaSea runtime gateway listening on %s", addr)
	log.Fatal(server.ListenAndServe())
}

func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func (a *app) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /_lunasea/api/capabilities", a.capabilities)
	mux.HandleFunc("GET /_lunasea/api/state", a.state)
	mux.HandleFunc("POST /_lunasea/api/profiles", a.createProfile)
	mux.HandleFunc("PATCH /_lunasea/api/profiles/{profile}", a.patchProfile)
	mux.HandleFunc("DELETE /_lunasea/api/profiles/{profile}", a.deleteProfile)
	mux.HandleFunc("PUT /_lunasea/api/profiles/{profile}/services/{service}", a.putProfileService)
	mux.HandleFunc("DELETE /_lunasea/api/profiles/{profile}/services/{service}", a.deleteProfileService)
	mux.HandleFunc("PATCH /_lunasea/api/preferences/app", a.patchAppPreferences)
	mux.HandleFunc("PATCH /_lunasea/api/preferences/modules/{module}", a.patchModulePreferences)
	mux.HandleFunc("POST /_lunasea/api/indexers", a.createIndexer)
	mux.HandleFunc("PATCH /_lunasea/api/indexers/{id}", a.patchIndexer)
	mux.HandleFunc("DELETE /_lunasea/api/indexers/{id}", a.deleteIndexer)
	mux.HandleFunc("GET /_lunasea/api/indexers/{id}/proxy", a.proxy.serveIndexerAPI)
	mux.HandleFunc("GET /_lunasea/api/indexers/{id}/download", a.proxy.serveIndexerDownload)
	mux.HandleFunc("POST /_lunasea/api/external-modules", a.createExternalModule)
	mux.HandleFunc("PATCH /_lunasea/api/external-modules/{id}", a.patchExternalModule)
	mux.HandleFunc("DELETE /_lunasea/api/external-modules/{id}", a.deleteExternalModule)
	mux.HandleFunc("PUT /_lunasea/api/banners/{key}", a.dismissBanner)
	mux.HandleFunc("DELETE /_lunasea/api/banners/{key}", a.undismissBanner)
	mux.HandleFunc("POST /_lunasea/api/logs", a.createLog)
	mux.HandleFunc("DELETE /_lunasea/api/logs", a.clearLogs)
	mux.HandleFunc("GET /_lunasea/api/services", a.listServices)
	mux.HandleFunc("PUT /_lunasea/api/services/{service}/{profile}", a.putService)
	mux.HandleFunc("POST /_lunasea/api/services/{service}/{profile}/test", a.testService)
	mux.HandleFunc("DELETE /_lunasea/api/services/{service}/{profile}", a.deleteService)
	mux.HandleFunc("/_lunasea/proxy/", a.proxy.serve)
	mux.HandleFunc("/", a.serveStatic)
	return mux
}

func (a *app) capabilities(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"gateway":  true,
		"version":  "1",
		"services": supportedServices,
	})
}

func (a *app) listServices(w http.ResponseWriter, r *http.Request) {
	configs, err := a.store.listServices(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	services := make([]serviceResponse, 0, len(configs))
	for _, cfg := range configs {
		services = append(services, cfg.redacted())
	}
	writeJSON(w, http.StatusOK, map[string]any{"services": services})
}

func (a *app) putService(w http.ResponseWriter, r *http.Request) {
	service, profile, ok := serviceRouteValues(w, r)
	if !ok {
		return
	}
	a.putServiceFor(w, r, service, profile)
}

func (a *app) putServiceFor(w http.ResponseWriter, r *http.Request, service, profile string) {
	var request serviceWriteRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "bad_json", err.Error())
		return
	}

	existing, err := a.store.getService(r.Context(), service, profile)
	if errors.Is(err, errNotFound) {
		existing = serviceConfig{
			Service: service,
			Profile: profile,
			Headers: map[string]string{},
		}
	} else if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}

	if request.UpstreamURL != nil {
		upstream, err := validateUpstream(*request.UpstreamURL)
		if err != nil {
			writeError(w, http.StatusBadRequest, "bad_upstream", err.Error())
			return
		}
		existing.UpstreamURL = upstream
	}
	if existing.UpstreamURL == "" {
		writeError(w, http.StatusBadRequest, "bad_upstream", "upstreamUrl is required")
		return
	}
	if request.APIKey != nil {
		existing.APIKey = *request.APIKey
	}
	if request.Username != nil {
		existing.Username = *request.Username
	}
	if request.Password != nil {
		existing.Password = *request.Password
	}
	if request.Headers != nil {
		existing.Headers = *request.Headers
	}
	if existing.Headers == nil {
		existing.Headers = map[string]string{}
	}

	if err := a.store.putService(r.Context(), existing); err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, existing.redacted())
}

func (a *app) testService(w http.ResponseWriter, r *http.Request) {
	service, profile, ok := serviceRouteValues(w, r)
	if !ok {
		return
	}

	cfg, err := a.store.getService(r.Context(), service, profile)
	if errors.Is(err, errNotFound) {
		writeError(w, http.StatusServiceUnavailable, "unconfigured", "Service is not configured")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()
	if err := testService(ctx, a.proxy.client, cfg); err != nil {
		writeError(w, http.StatusBadGateway, "upstream_error", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (a *app) deleteService(w http.ResponseWriter, r *http.Request) {
	service, profile, ok := serviceRouteValues(w, r)
	if !ok {
		return
	}
	err := a.store.deleteService(r.Context(), service, profile)
	if errors.Is(err, errNotFound) {
		writeError(w, http.StatusServiceUnavailable, "unconfigured", "Service is not configured")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func serviceRouteValues(w http.ResponseWriter, r *http.Request) (string, string, bool) {
	service := r.PathValue("service")
	profile := r.PathValue("profile")
	if err := validateService(service); err != nil {
		writeError(w, http.StatusNotFound, "unsupported_service", err.Error())
		return "", "", false
	}
	if err := validateProfile(profile); err != nil {
		writeError(w, http.StatusBadRequest, "bad_profile", err.Error())
		return "", "", false
	}
	return service, profile, true
}

func (a *app) serveStatic(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "Method not allowed")
		return
	}

	cleanPath := filepath.Clean(strings.TrimPrefix(r.URL.Path, "/"))
	if cleanPath == "." {
		cleanPath = "index.html"
	}
	fullPath := filepath.Join(a.staticDir, cleanPath)
	if !strings.HasPrefix(fullPath, filepath.Clean(a.staticDir)+string(os.PathSeparator)) && fullPath != filepath.Clean(a.staticDir) {
		writeError(w, http.StatusNotFound, "not_found", "File not found")
		return
	}
	info, err := os.Stat(fullPath)
	if err != nil || info.IsDir() {
		fullPath = filepath.Join(a.staticDir, "index.html")
	}
	setStaticCacheHeaders(w, filepath.Base(fullPath))
	http.ServeFile(w, r, fullPath)
}

func setStaticCacheHeaders(w http.ResponseWriter, name string) {
	switch name {
	case "index.html", "flutter_bootstrap.js", "flutter_service_worker.js", "main.dart.js":
		w.Header().Set("Cache-Control", "no-store")
	default:
		w.Header().Set("Cache-Control", "public, max-age=3600")
	}
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]any{
		"error": map[string]string{
			"code":    code,
			"message": message,
		},
	})
}
