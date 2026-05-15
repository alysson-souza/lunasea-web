package main

import (
	"encoding/json"
	"errors"
	"net/url"
	"slices"
	"strings"
)

const (
	serviceLidarr   = "lidarr"
	serviceNZBGet   = "nzbget"
	serviceRadarr   = "radarr"
	serviceSABnzbd  = "sabnzbd"
	serviceSonarr   = "sonarr"
	serviceTautulli = "tautulli"
)

var supportedServices = []string{
	serviceLidarr,
	serviceNZBGet,
	serviceRadarr,
	serviceSABnzbd,
	serviceSonarr,
	serviceTautulli,
}

type serviceConfig struct {
	Service     string            `json:"service"`
	Profile     string            `json:"profile"`
	UpstreamURL string            `json:"upstreamUrl"`
	APIKey      string            `json:"apiKey,omitempty"`
	Username    string            `json:"username,omitempty"`
	Password    string            `json:"password,omitempty"`
	Headers     map[string]string `json:"headers,omitempty"`
}

type serviceResponse struct {
	Service     string `json:"service"`
	Profile     string `json:"profile"`
	Enabled     bool   `json:"enabled"`
	UpstreamURL string `json:"upstreamUrl"`
	ProxyPath   string `json:"proxyPath"`
	HasAPIKey   bool   `json:"hasApiKey"`
	HasUsername bool   `json:"hasUsername"`
	HasPassword bool   `json:"hasPassword"`
}

type serviceWriteRequest struct {
	UpstreamURL *string            `json:"upstreamUrl"`
	APIKey      *string            `json:"apiKey"`
	Username    *string            `json:"username"`
	Password    *string            `json:"password"`
	Headers     *map[string]string `json:"headers"`
}

func (cfg serviceConfig) redacted() serviceResponse {
	return serviceResponse{
		Service:     cfg.Service,
		Profile:     cfg.Profile,
		Enabled:     true,
		UpstreamURL: cfg.UpstreamURL,
		ProxyPath:   proxyPrefix(cfg.Service, cfg.Profile),
		HasAPIKey:   cfg.APIKey != "",
		HasUsername: cfg.Username != "",
		HasPassword: cfg.Password != "",
	}
}

func validateService(service string) error {
	if slices.Contains(supportedServices, service) {
		return nil
	}
	return errors.New("unsupported service")
}

func validateProfile(profile string) error {
	if profile == "" {
		return errors.New("profile is required")
	}
	for _, r := range profile {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') ||
			(r >= '0' && r <= '9') || r == '-' || r == '_' || r == '.' {
			continue
		}
		return errors.New("profile may only contain letters, numbers, dots, dashes, and underscores")
	}
	return nil
}

func validateUpstream(raw string) (string, error) {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return "", errors.New("upstreamUrl is required")
	}
	parsed, err := url.Parse(trimmed)
	if err != nil {
		return "", err
	}
	if parsed.Scheme != "http" && parsed.Scheme != "https" {
		return "", errors.New("upstreamUrl must start with http:// or https://")
	}
	if parsed.Host == "" {
		return "", errors.New("upstreamUrl must include a host")
	}
	parsed.Fragment = ""
	return strings.TrimRight(parsed.String(), "/"), nil
}

func marshalHeaders(headers map[string]string) (string, error) {
	if headers == nil {
		headers = map[string]string{}
	}
	data, err := json.Marshal(headers)
	return string(data), err
}

func unmarshalHeaders(data string) map[string]string {
	if data == "" {
		return map[string]string{}
	}
	headers := map[string]string{}
	if err := json.Unmarshal([]byte(data), &headers); err != nil {
		return map[string]string{}
	}
	return headers
}
