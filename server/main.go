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
	mux.HandleFunc("POST /_lunasea/api/profiles/{profile}/services/{service}/instances", a.createServiceInstance)
	mux.HandleFunc("PATCH /_lunasea/api/profiles/{profile}/services/{service}/instances/{instance}", a.patchServiceInstance)
	mux.HandleFunc("DELETE /_lunasea/api/profiles/{profile}/services/{service}/instances/{instance}", a.deleteServiceInstance)
	mux.HandleFunc("POST /_lunasea/api/profiles/{profile}/services/{service}/instances/{instance}/test", a.testServiceInstance)
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
		if !cfg.Enabled || cfg.UpstreamURL == "" {
			continue
		}
		services = append(services, cfg.redacted())
	}
	writeJSON(w, http.StatusOK, map[string]any{"services": services})
}

func (a *app) createServiceInstance(w http.ResponseWriter, r *http.Request) {
	service, profile, ok := serviceRouteValues(w, r)
	if !ok {
		return
	}
	var request serviceWriteRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "bad_json", err.Error())
		return
	}
	cfg := serviceConfig{
		Service:        service,
		Profile:        profile,
		InstanceID:     newServiceInstanceID(),
		DisplayName:    service,
		Enabled:        false,
		ConnectionMode: "gateway",
		Headers:        map[string]string{},
	}
	if !applyServiceWriteRequest(w, &cfg, request) {
		return
	}
	if err := a.store.putService(r.Context(), cfg); err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, cfg.redacted())
}

func (a *app) patchServiceInstance(w http.ResponseWriter, r *http.Request) {
	service, profile, instanceID, ok := serviceInstanceRouteValues(w, r)
	if !ok {
		return
	}
	var request serviceWriteRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "bad_json", err.Error())
		return
	}
	cfg, err := a.store.getService(r.Context(), service, profile, instanceID)
	if errors.Is(err, errNotFound) {
		writeError(w, http.StatusNotFound, "service_not_found", "Service instance was not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	if !applyServiceWriteRequest(w, &cfg, request) {
		return
	}
	if err := a.store.putService(r.Context(), cfg); err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, cfg.redacted())
}

func (a *app) deleteServiceInstance(w http.ResponseWriter, r *http.Request) {
	service, profile, instanceID, ok := serviceInstanceRouteValues(w, r)
	if !ok {
		return
	}
	err := a.store.deleteService(r.Context(), service, profile, instanceID)
	if errors.Is(err, errNotFound) {
		writeError(w, http.StatusServiceUnavailable, "unconfigured", "Service instance was not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *app) testServiceInstance(w http.ResponseWriter, r *http.Request) {
	service, profile, instanceID, ok := serviceInstanceRouteValues(w, r)
	if !ok {
		return
	}
	cfg, err := a.store.getService(r.Context(), service, profile, instanceID)
	if errors.Is(err, errNotFound) {
		writeError(w, http.StatusServiceUnavailable, "unconfigured", "Service instance was not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	if cfg.UpstreamURL == "" {
		writeError(w, http.StatusServiceUnavailable, "unconfigured", "Service instance has no upstream URL configured")
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

func applyServiceWriteRequest(w http.ResponseWriter, cfg *serviceConfig, request serviceWriteRequest) bool {
	if request.DisplayName != nil {
		cfg.DisplayName = *request.DisplayName
	}
	if request.Enabled != nil {
		cfg.Enabled = *request.Enabled
	}
	if request.SortOrder != nil {
		cfg.SortOrder = *request.SortOrder
	}
	if request.ConnectionMode != nil {
		cfg.ConnectionMode = *request.ConnectionMode
	}
	if request.Preferences != nil {
		cfg.Preferences = *request.Preferences
	}
	if request.UpstreamURL != nil {
		upstream := strings.TrimSpace(*request.UpstreamURL)
		if upstream != "" {
			var err error
			upstream, err = validateUpstream(upstream)
			if err != nil {
				writeError(w, http.StatusBadRequest, "bad_upstream", err.Error())
				return false
			}
		}
		cfg.UpstreamURL = upstream
	}
	if request.APIKey != nil && *request.APIKey != "" {
		cfg.APIKey = *request.APIKey
	}
	if request.Username != nil && *request.Username != "" {
		cfg.Username = *request.Username
	}
	if request.Password != nil && *request.Password != "" {
		cfg.Password = *request.Password
	}
	if request.Headers != nil && len(*request.Headers) > 0 {
		cfg.Headers = *request.Headers
	}
	if cfg.Headers == nil {
		cfg.Headers = map[string]string{}
	}
	return true
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

func serviceInstanceRouteValues(w http.ResponseWriter, r *http.Request) (string, string, string, bool) {
	service, profile, ok := serviceRouteValues(w, r)
	if !ok {
		return "", "", "", false
	}
	instanceID := r.PathValue("instance")
	if err := validateInstanceID(instanceID); err != nil {
		writeError(w, http.StatusBadRequest, "bad_instance", err.Error())
		return "", "", "", false
	}
	return service, profile, instanceID, true
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
