package main

import (
	"bytes"
	"context"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"path"
	"regexp"
	"strconv"
	"strings"
	"time"
)

type proxyHandler struct {
	store  *store
	client *http.Client
}

func newProxyHandler(store *store) *proxyHandler {
	return &proxyHandler{
		store: store,
		client: &http.Client{
			Timeout: 60 * time.Second,
		},
	}
}

func proxyPrefix(service, profile string) string {
	return "/_lunasea/proxy/" + service + "/" + profile + "/"
}

func (h *proxyHandler) serve(w http.ResponseWriter, r *http.Request) {
	service, profile, suffix, ok := parseProxyPath(r.URL.Path)
	if !ok {
		writeError(w, http.StatusNotFound, "not_found", "Proxy route not found")
		return
	}
	cfg, err := h.store.getService(r.Context(), service, profile)
	if errors.Is(err, errNotFound) {
		writeError(w, http.StatusServiceUnavailable, "unconfigured", "Service is not configured")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	upstream, err := buildUpstreamURL(cfg.UpstreamURL, suffix, r.URL.RawQuery)
	if err != nil {
		writeError(w, http.StatusBadGateway, "bad_upstream", err.Error())
		return
	}

	var body io.Reader
	if r.Body != nil {
		defer r.Body.Close()
		data, err := io.ReadAll(r.Body)
		if err != nil {
			writeError(w, http.StatusBadRequest, "bad_request", err.Error())
			return
		}
		body = bytes.NewReader(data)
	}

	req, err := http.NewRequestWithContext(r.Context(), r.Method, upstream.String(), body)
	if err != nil {
		writeError(w, http.StatusBadGateway, "bad_upstream", err.Error())
		return
	}
	copyRequestHeaders(req.Header, r.Header)
	injectServiceAuth(req, cfg)

	resp, err := h.client.Do(req)
	if err != nil {
		writeError(w, http.StatusBadGateway, "upstream_error", err.Error())
		return
	}
	defer resp.Body.Close()

	copyResponseHeaders(w.Header(), resp.Header)
	w.WriteHeader(resp.StatusCode)
	_, _ = io.Copy(w, resp.Body)
}

func (h *proxyHandler) serveIndexerAPI(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(r.PathValue("id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_indexer", "Invalid indexer ID")
		return
	}
	indexer, err := h.store.getIndexer(r.Context(), id, true)
	if errors.Is(err, errNotFound) {
		writeError(w, http.StatusNotFound, "indexer_not_found", "Indexer was not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	upstream, err := buildUpstreamURL(indexer.Host, "api", r.URL.RawQuery)
	if err != nil {
		writeError(w, http.StatusBadGateway, "bad_upstream", err.Error())
		return
	}
	req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, upstream.String(), nil)
	if err != nil {
		writeError(w, http.StatusBadGateway, "bad_upstream", err.Error())
		return
	}
	copyRequestHeaders(req.Header, r.Header)
	injectIndexerAuth(req, indexer)

	resp, err := h.client.Do(req)
	if err != nil {
		writeError(w, http.StatusBadGateway, "upstream_error", err.Error())
		return
	}
	defer resp.Body.Close()

	copyResponseHeaders(w.Header(), resp.Header)
	w.WriteHeader(resp.StatusCode)
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return
	}
	_, _ = w.Write(rewriteIndexerLinks(r, data, indexer, id))
}

func (h *proxyHandler) serveIndexerDownload(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(r.PathValue("id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_indexer", "Invalid indexer ID")
		return
	}
	target := r.URL.Query().Get("url")
	if target == "" {
		writeError(w, http.StatusBadRequest, "bad_download", "Missing download URL")
		return
	}
	indexer, err := h.store.getIndexer(r.Context(), id, true)
	if errors.Is(err, errNotFound) {
		writeError(w, http.StatusNotFound, "indexer_not_found", "Indexer was not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	upstream, err := resolveIndexerDownloadURL(indexer.Host, target)
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_download", err.Error())
		return
	}
	req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, upstream.String(), nil)
	if err != nil {
		writeError(w, http.StatusBadGateway, "bad_upstream", err.Error())
		return
	}
	copyRequestHeaders(req.Header, r.Header)
	injectIndexerAuth(req, indexer)

	resp, err := h.client.Do(req)
	if err != nil {
		writeError(w, http.StatusBadGateway, "upstream_error", err.Error())
		return
	}
	defer resp.Body.Close()

	copyResponseHeaders(w.Header(), resp.Header)
	w.WriteHeader(resp.StatusCode)
	_, _ = io.Copy(w, resp.Body)
}

func parseProxyPath(rawPath string) (service, profile, suffix string, ok bool) {
	const prefix = "/_lunasea/proxy/"
	if !strings.HasPrefix(rawPath, prefix) {
		return "", "", "", false
	}
	rest := strings.TrimPrefix(rawPath, prefix)
	parts := strings.SplitN(rest, "/", 3)
	if len(parts) < 2 {
		return "", "", "", false
	}
	service = parts[0]
	profile = parts[1]
	if validateService(service) != nil || validateProfile(profile) != nil {
		return "", "", "", false
	}
	if len(parts) == 3 {
		suffix = parts[2]
	}
	if hasUnsafePathSegment(suffix) {
		return "", "", "", false
	}
	return service, profile, suffix, true
}

func hasUnsafePathSegment(value string) bool {
	for _, segment := range strings.Split(value, "/") {
		if segment == "." || segment == ".." {
			return true
		}
	}
	return false
}

func buildUpstreamURL(baseRaw, suffix, rawQuery string) (*url.URL, error) {
	base, err := url.Parse(baseRaw)
	if err != nil {
		return nil, err
	}
	if base.Scheme != "http" && base.Scheme != "https" {
		return nil, errors.New("upstream URL must use http or https")
	}
	if hasUnsafePathSegment(suffix) {
		return nil, errors.New("unsafe proxy path")
	}
	joined := *base
	if suffix != "" {
		basePath := strings.TrimRight(joined.Path, "/")
		joined.Path = basePath + "/" + strings.TrimLeft(suffix, "/")
		joined.RawPath = ""
	}
	if joined.Path == "" {
		joined.Path = "/"
	}
	joined.Path = path.Clean(joined.Path)
	if strings.HasSuffix(suffix, "/") && !strings.HasSuffix(joined.Path, "/") {
		joined.Path += "/"
	}
	joined.RawQuery = rawQuery
	return &joined, nil
}

func copyRequestHeaders(dst, src http.Header) {
	for key, values := range src {
		lower := strings.ToLower(key)
		switch lower {
		case "host", "connection", "content-length", "accept-encoding", "authorization", "cookie":
			continue
		}
		for _, value := range values {
			dst.Add(key, value)
		}
	}
}

func copyResponseHeaders(dst, src http.Header) {
	for key, values := range src {
		lower := strings.ToLower(key)
		switch lower {
		case "connection", "content-length", "transfer-encoding":
			continue
		}
		for _, value := range values {
			dst.Add(key, value)
		}
	}
}

func injectServiceAuth(req *http.Request, cfg serviceConfig) {
	for key, value := range cfg.Headers {
		req.Header.Set(key, value)
	}
	switch cfg.Service {
	case serviceLidarr, serviceRadarr, serviceSonarr:
		if cfg.APIKey != "" {
			query := req.URL.Query()
			query.Del("apikey")
			req.URL.RawQuery = query.Encode()
			req.Header.Set("X-Api-Key", cfg.APIKey)
		}
	case serviceSABnzbd, serviceTautulli:
		if cfg.APIKey != "" {
			query := req.URL.Query()
			query.Set("apikey", cfg.APIKey)
			req.URL.RawQuery = query.Encode()
		}
	case serviceNZBGet:
		if cfg.Username != "" || cfg.Password != "" {
			req.SetBasicAuth(cfg.Username, cfg.Password)
		}
	}
}

func injectIndexerAuth(req *http.Request, indexer indexerRecord) {
	for key, value := range indexer.Headers {
		req.Header.Set(key, value)
	}
	if req.Header.Get("User-Agent") == "" {
		req.Header.Set("User-Agent", "LunaSea-Web")
	}
	if indexer.APIKey != "" {
		query := req.URL.Query()
		query.Del("apikey")
		query.Set("apikey", indexer.APIKey)
		req.URL.RawQuery = query.Encode()
	}
}

func redactIndexerResponse(data []byte, indexer indexerRecord) []byte {
	if indexer.APIKey == "" {
		return data
	}
	redacted := bytes.ReplaceAll(data, []byte(url.QueryEscape(indexer.APIKey)), []byte(""))
	return bytes.ReplaceAll(redacted, []byte(indexer.APIKey), []byte(""))
}

var indexerLinkPattern = regexp.MustCompile(`(?s)<link>(.*?)</link>`)

func rewriteIndexerLinks(r *http.Request, data []byte, indexer indexerRecord, id int) []byte {
	redacted := redactIndexerResponse(data, indexer)
	return indexerLinkPattern.ReplaceAllFunc(redacted, func(match []byte) []byte {
		parts := indexerLinkPattern.FindSubmatch(match)
		if len(parts) != 2 {
			return match
		}
		link, err := url.QueryUnescape(string(parts[1]))
		if err != nil {
			link = string(parts[1])
		}
		link = strings.ReplaceAll(link, "&amp;", "&")
		target, err := resolveIndexerDownloadURL(indexer.Host, link)
		if err != nil {
			return match
		}
		return []byte("<link>" + xmlText(absoluteIndexerDownloadURL(r, id, target.String())) + "</link>")
	})
}

func xmlText(value string) string {
	var out bytes.Buffer
	_ = xml.EscapeText(&out, []byte(value))
	return out.String()
}

func absoluteIndexerDownloadURL(r *http.Request, id int, target string) string {
	scheme := r.Header.Get("X-Forwarded-Proto")
	if scheme == "" {
		scheme = "http"
		if r.TLS != nil {
			scheme = "https"
		}
	}
	host := r.Host
	if forwardedHost := r.Header.Get("X-Forwarded-Host"); forwardedHost != "" {
		host = forwardedHost
	}
	return fmt.Sprintf("%s://%s/_lunasea/api/indexers/%d/download?url=%s", scheme, host, id, url.QueryEscape(target))
}

func resolveIndexerDownloadURL(baseRaw, targetRaw string) (*url.URL, error) {
	base, err := url.Parse(baseRaw)
	if err != nil {
		return nil, err
	}
	if base.Scheme != "http" && base.Scheme != "https" {
		return nil, errors.New("indexer URL must use http or https")
	}
	target, err := url.Parse(targetRaw)
	if err != nil {
		return nil, err
	}
	resolved := base.ResolveReference(target)
	if resolved.Scheme != "http" && resolved.Scheme != "https" {
		return nil, errors.New("download URL must use http or https")
	}
	if resolved.Host != base.Host {
		return nil, errors.New("download URL must belong to the configured indexer")
	}
	query := resolved.Query()
	query.Del("apikey")
	resolved.RawQuery = query.Encode()
	return resolved, nil
}

func testService(ctx context.Context, client *http.Client, cfg serviceConfig) error {
	suffix, rawQuery, method, body := testRequest(cfg.Service)
	upstream, err := buildUpstreamURL(cfg.UpstreamURL, suffix, rawQuery)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, method, upstream.String(), body)
	if err != nil {
		return err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	injectServiceAuth(req, cfg)
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return errors.New(resp.Status)
	}
	return nil
}

func testRequest(service string) (suffix, rawQuery, method string, body io.Reader) {
	switch service {
	case serviceLidarr:
		return "api/v1/system/status", "", http.MethodGet, nil
	case serviceRadarr, serviceSonarr:
		return "api/v3/system/status", "", http.MethodGet, nil
	case serviceSABnzbd:
		return "api", "mode=version&output=json", http.MethodGet, nil
	case serviceNZBGet:
		data, _ := json.Marshal(map[string]any{
			"jsonrpc": "2.0",
			"method":  "version",
			"params":  []any{},
			"id":      1,
		})
		return "jsonrpc", "", http.MethodPost, bytes.NewReader(data)
	case serviceTautulli:
		return "api/v2", "cmd=status", http.MethodGet, nil
	default:
		return "", "", http.MethodGet, nil
	}
}
