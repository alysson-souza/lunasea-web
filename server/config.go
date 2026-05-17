package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/url"
	"regexp"
	"slices"
	"strings"
)

const (
	defaultServiceInstanceID = "default"

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

var serviceInstanceIDPattern = regexp.MustCompile(`^[A-Za-z0-9_-]+$`)

type serviceConfig struct {
	Service        string            `json:"service"`
	Profile        string            `json:"profile"`
	InstanceID     string            `json:"id"`
	DisplayName    string            `json:"displayName"`
	Enabled        bool              `json:"enabled"`
	SortOrder      int               `json:"sortOrder"`
	ConnectionMode string            `json:"connectionMode"`
	Preferences    map[string]any    `json:"preferences,omitempty"`
	UpstreamURL    string            `json:"upstreamUrl"`
	APIKey         string            `json:"apiKey,omitempty"`
	Username       string            `json:"username,omitempty"`
	Password       string            `json:"password,omitempty"`
	Headers        map[string]string `json:"headers,omitempty"`
}

type serviceResponse struct {
	Service        string         `json:"service"`
	Profile        string         `json:"profile"`
	InstanceID     string         `json:"id"`
	DisplayName    string         `json:"displayName"`
	Enabled        bool           `json:"enabled"`
	SortOrder      int            `json:"sortOrder"`
	ConnectionMode string         `json:"connectionMode"`
	Preferences    map[string]any `json:"preferences,omitempty"`
	UpstreamURL    string         `json:"upstreamUrl"`
	ProxyPath      string         `json:"proxyPath"`
	HasAPIKey      bool           `json:"hasApiKey"`
	HasUsername    bool           `json:"hasUsername"`
	HasPassword    bool           `json:"hasPassword"`
}

type serviceWriteRequest struct {
	DisplayName    *string            `json:"displayName"`
	Enabled        *bool              `json:"enabled"`
	SortOrder      *int               `json:"sortOrder"`
	ConnectionMode *string            `json:"connectionMode"`
	Preferences    *map[string]any    `json:"preferences"`
	UpstreamURL    *string            `json:"upstreamUrl"`
	APIKey         *string            `json:"apiKey"`
	Username       *string            `json:"username"`
	Password       *string            `json:"password"`
	Headers        *map[string]string `json:"headers"`
}

func (cfg serviceConfig) redacted() serviceResponse {
	instanceID := cfg.InstanceID
	if instanceID == "" {
		instanceID = defaultServiceInstanceID
	}
	displayName := cfg.DisplayName
	if displayName == "" {
		displayName = cfg.Service
	}
	connectionMode := cfg.ConnectionMode
	if connectionMode == "" {
		connectionMode = "gateway"
	}

	return serviceResponse{
		Service:        cfg.Service,
		Profile:        cfg.Profile,
		InstanceID:     instanceID,
		DisplayName:    displayName,
		Enabled:        cfg.Enabled,
		SortOrder:      cfg.SortOrder,
		ConnectionMode: connectionMode,
		Preferences:    cfg.Preferences,
		UpstreamURL:    cfg.UpstreamURL,
		ProxyPath:      proxyPrefix(cfg.Service, cfg.Profile, instanceID),
		HasAPIKey:      cfg.APIKey != "",
		HasUsername:    cfg.Username != "",
		HasPassword:    cfg.Password != "",
	}
}

func newServiceInstanceID() string {
	var data [16]byte
	if _, err := rand.Read(data[:]); err != nil {
		panic(err)
	}
	return hex.EncodeToString(data[:])
}

func validateInstanceID(instanceID string) error {
	if instanceID == "" {
		return errors.New("instance id is required")
	}
	if !serviceInstanceIDPattern.MatchString(instanceID) {
		return errors.New("instance id may only contain letters, numbers, dashes, and underscores")
	}
	return nil
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
