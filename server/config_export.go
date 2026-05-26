package main

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"
)

const (
	configFormat             = "lunasea-web-config"
	configVersion            = 1
	importServiceTestTimeout = 15 * time.Second
)

type configDocument struct {
	Format            string                    `json:"format"`
	Version           int                       `json:"version"`
	ActiveProfile     string                    `json:"activeProfile"`
	Profiles          []profileRecord           `json:"profiles"`
	ServiceInstances  []serviceConfig           `json:"serviceInstances"`
	Preferences       map[string]any            `json:"preferences"`
	ModulePreferences map[string]map[string]any `json:"modulePreferences"`
	Indexers          []indexerRecord           `json:"indexers"`
	ExternalModules   []externalModuleRecord    `json:"externalModules"`
	DismissedBanners  []string                  `json:"dismissedBanners"`
}

type instancesXML struct {
	XMLName   xml.Name             `xml:"instances"`
	Instances []serviceInstanceXML `xml:"instance"`
}

type serviceInstanceXML struct {
	Service        string      `xml:"service"`
	DisplayName    string      `xml:"displayName"`
	Profile        string      `xml:"profile"`
	InstanceID     string      `xml:"id"`
	Enabled        string      `xml:"enabled"`
	SortOrder      int         `xml:"sortOrder"`
	ConnectionMode string      `xml:"connectionMode"`
	UpstreamURL    string      `xml:"upstreamUrl"`
	URL            string      `xml:"url"`
	APIKey         string      `xml:"apiKey"`
	Username       string      `xml:"username"`
	Password       string      `xml:"password"`
	Headers        []headerXML `xml:"headers>header"`
}

type headerXML struct {
	Key   string `xml:"key,attr"`
	Value string `xml:",chardata"`
}

func (a *app) exportConfig(w http.ResponseWriter, r *http.Request) {
	doc, err := a.store.configSnapshot(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	w.Header().Set("Content-Disposition", `attachment; filename="lunasea-web-config.json"`)
	writeJSON(w, http.StatusOK, doc)
}

func (a *app) importConfig(w http.ResponseWriter, r *http.Request) {
	data, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 10<<20))
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_config_import", err.Error())
		return
	}
	trimmed := bytes.TrimSpace(data)
	if len(trimmed) == 0 {
		writeError(w, http.StatusBadRequest, "bad_config_import", "configuration file is empty")
		return
	}

	if trimmed[0] == '<' {
		instances, err := serviceInstancesFromXML(trimmed)
		if err != nil {
			writeError(w, http.StatusBadRequest, "bad_config_import", err.Error())
			return
		}
		normalized, profiles, err := normalizeServiceInstances(instances, nil)
		if err != nil {
			writeError(w, http.StatusBadRequest, "bad_config_import", err.Error())
			return
		}
		normalized = a.testImportedServiceInstances(r.Context(), normalized)
		if err := a.store.replaceNormalizedServiceInstances(r.Context(), normalized, profiles); err != nil {
			writeError(w, http.StatusBadRequest, "bad_config_import", err.Error())
			return
		}
	} else {
		doc, err := decodeConfigDocument(trimmed)
		if err != nil {
			writeError(w, http.StatusBadRequest, "bad_config_import", err.Error())
			return
		}
		if err := normalizeConfigDocument(&doc); err != nil {
			writeError(w, http.StatusBadRequest, "bad_config_import", err.Error())
			return
		}
		doc.ServiceInstances = a.testImportedServiceInstances(r.Context(), doc.ServiceInstances)
		if err := a.store.replaceNormalizedConfig(r.Context(), doc); err != nil {
			writeError(w, http.StatusBadRequest, "bad_config_import", err.Error())
			return
		}
	}

	state, err := a.store.stateSnapshot(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, state)
}

func (a *app) testImportedServiceInstances(ctx context.Context, services []serviceConfig) []serviceConfig {
	tested := make([]serviceConfig, len(services))
	copy(tested, services)

	var wg sync.WaitGroup
	for i := range tested {
		i := i
		wg.Add(1)
		go func() {
			defer wg.Done()
			tested[i].Enabled = a.importedServiceAvailable(ctx, tested[i])
		}()
	}
	wg.Wait()
	return tested
}

func (a *app) importedServiceAvailable(ctx context.Context, cfg serviceConfig) bool {
	if cfg.UpstreamURL == "" {
		return false
	}
	testCtx, cancel := context.WithTimeout(ctx, importServiceTestTimeout)
	defer cancel()
	return testService(testCtx, a.proxy.client, cfg) == nil
}

func (s *store) configSnapshot(ctx context.Context) (configDocument, error) {
	profiles, err := s.listProfiles(ctx)
	if err != nil {
		return configDocument{}, err
	}
	services, err := s.listServiceInstances(ctx)
	if err != nil {
		return configDocument{}, err
	}
	appPrefs, err := s.preferenceMap(ctx, "app_preferences", appPreferenceFields)
	if err != nil {
		return configDocument{}, err
	}
	modulePrefs := map[string]map[string]any{}
	for service, table := range modulePreferenceTables {
		prefs, err := s.preferenceMap(ctx, table, modulePreferenceFields[service])
		if err != nil {
			return configDocument{}, err
		}
		modulePrefs[service] = prefs
	}
	indexers, err := s.listIndexers(ctx, true)
	if err != nil {
		return configDocument{}, err
	}
	externalModules, err := s.listExternalModules(ctx)
	if err != nil {
		return configDocument{}, err
	}
	banners, err := s.listDismissedBanners(ctx)
	if err != nil {
		return configDocument{}, err
	}
	active, _ := appPrefs["activeProfile"].(string)
	return configDocument{
		Format:            configFormat,
		Version:           configVersion,
		ActiveProfile:     active,
		Profiles:          profiles,
		ServiceInstances:  services,
		Preferences:       appPrefs,
		ModulePreferences: modulePrefs,
		Indexers:          indexers,
		ExternalModules:   externalModules,
		DismissedBanners:  banners,
	}, nil
}

func decodeConfigDocument(data []byte) (configDocument, error) {
	var doc configDocument
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&doc); err != nil {
		return configDocument{}, fmt.Errorf("invalid JSON: %w", err)
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		return configDocument{}, errors.New("invalid JSON: multiple documents")
	}
	return doc, nil
}

func serviceInstancesFromXML(data []byte) ([]serviceConfig, error) {
	var doc instancesXML
	decoder := xml.NewDecoder(bytes.NewReader(data))
	if err := decoder.Decode(&doc); err != nil {
		return nil, fmt.Errorf("invalid XML: %w", err)
	}
	if doc.XMLName.Local != "instances" {
		return nil, errors.New("invalid XML: expected <instances>")
	}
	if len(doc.Instances) == 0 {
		return nil, errors.New("invalid XML: no service instances found")
	}

	instances := make([]serviceConfig, 0, len(doc.Instances))
	for i, item := range doc.Instances {
		enabled, err := xmlBool(item.Enabled, true)
		if err != nil {
			return nil, fmt.Errorf("instance %d enabled: %w", i+1, err)
		}
		headers := map[string]string{}
		for _, header := range item.Headers {
			key := strings.TrimSpace(header.Key)
			if key == "" {
				return nil, fmt.Errorf("instance %d header key is required", i+1)
			}
			headers[key] = strings.TrimSpace(header.Value)
		}
		instances = append(instances, serviceConfig{
			Service:        strings.TrimSpace(item.Service),
			Profile:        strings.TrimSpace(item.Profile),
			InstanceID:     strings.TrimSpace(item.InstanceID),
			DisplayName:    strings.TrimSpace(item.DisplayName),
			Enabled:        enabled,
			SortOrder:      item.SortOrder,
			ConnectionMode: strings.TrimSpace(item.ConnectionMode),
			UpstreamURL:    xmlUpstreamURL(item),
			APIKey:         strings.TrimSpace(item.APIKey),
			Username:       strings.TrimSpace(item.Username),
			Password:       strings.TrimSpace(item.Password),
			Headers:        headers,
			Preferences:    map[string]any{},
		})
	}
	return instances, nil
}

func xmlUpstreamURL(item serviceInstanceXML) string {
	if value := strings.TrimSpace(item.UpstreamURL); value != "" {
		return value
	}
	return strings.TrimSpace(item.URL)
}

func xmlBool(value string, fallback bool) (bool, error) {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "":
		return fallback, nil
	case "true", "1", "yes":
		return true, nil
	case "false", "0", "no":
		return false, nil
	default:
		return false, fmt.Errorf("%q is not a boolean", value)
	}
}

func (s *store) replaceConfig(ctx context.Context, doc configDocument) error {
	if err := normalizeConfigDocument(&doc); err != nil {
		return err
	}
	return s.replaceNormalizedConfig(ctx, doc)
}

func (s *store) replaceNormalizedConfig(ctx context.Context, doc configDocument) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	now := nowText()
	if _, err := tx.ExecContext(ctx, `DELETE FROM service_instances;`); err != nil {
		return err
	}
	if err := upsertProfilesTx(ctx, tx, doc.Profiles, now); err != nil {
		return err
	}
	if err := resetPreferencesTx(ctx, tx, doc.ActiveProfile, now); err != nil {
		return err
	}
	if err := updatePreferencesTx(ctx, tx, "app_preferences", appPreferenceFields, doc.Preferences); err != nil {
		return err
	}
	for module, prefs := range doc.ModulePreferences {
		if err := updatePreferencesTx(ctx, tx, modulePreferenceTables[module], modulePreferenceFields[module], prefs); err != nil {
			return err
		}
	}
	if err := deleteProfilesNotInTx(ctx, tx, doc.profileIDSet()); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM indexers;`); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM external_modules;`); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM dismissed_banners;`); err != nil {
		return err
	}
	for _, service := range doc.ServiceInstances {
		if err := insertServiceTx(ctx, tx, service, now); err != nil {
			return err
		}
	}
	for _, indexer := range doc.Indexers {
		if err := insertIndexerTx(ctx, tx, indexer, now); err != nil {
			return err
		}
	}
	for _, module := range doc.ExternalModules {
		if err := insertExternalModuleTx(ctx, tx, module, now); err != nil {
			return err
		}
	}
	for _, key := range doc.DismissedBanners {
		if _, err := tx.ExecContext(ctx, `
INSERT INTO dismissed_banners (key, dismissed_at)
VALUES (?, ?);`, key, now); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (s *store) replaceServiceInstances(ctx context.Context, services []serviceConfig) error {
	normalized, profiles, err := normalizeServiceInstances(services, nil)
	if err != nil {
		return err
	}
	return s.replaceNormalizedServiceInstances(ctx, normalized, profiles)
}

func (s *store) replaceNormalizedServiceInstances(ctx context.Context, normalized []serviceConfig, profiles map[string]bool) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	now := nowText()
	if _, err := tx.ExecContext(ctx, `DELETE FROM service_instances;`); err != nil {
		return err
	}
	for profile := range profiles {
		if _, err := tx.ExecContext(ctx, `
INSERT INTO profiles (id, display_name, sort_order, created_at, updated_at)
VALUES (?, ?, 0, ?, ?)
ON CONFLICT(id) DO NOTHING;`, profile, profile, now, now); err != nil {
			return err
		}
	}
	for _, service := range normalized {
		if err := insertServiceTx(ctx, tx, service, now); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func normalizeConfigDocument(doc *configDocument) error {
	if doc.Format != configFormat {
		return fmt.Errorf("unsupported config format %q", doc.Format)
	}
	if doc.Version != configVersion {
		return fmt.Errorf("unsupported config version %d", doc.Version)
	}
	if doc.Preferences == nil {
		doc.Preferences = map[string]any{}
	}
	if doc.ModulePreferences == nil {
		doc.ModulePreferences = map[string]map[string]any{}
	}
	if doc.Indexers == nil {
		doc.Indexers = []indexerRecord{}
	}
	if doc.ExternalModules == nil {
		doc.ExternalModules = []externalModuleRecord{}
	}
	if doc.DismissedBanners == nil {
		doc.DismissedBanners = []string{}
	}
	if doc.ActiveProfile == "" {
		if active, ok := doc.Preferences["activeProfile"].(string); ok {
			doc.ActiveProfile = active
		}
	}
	if doc.ActiveProfile == "" {
		return errors.New("activeProfile is required")
	}

	profiles, err := normalizeProfiles(doc.Profiles)
	if err != nil {
		return err
	}
	if !profiles[doc.ActiveProfile] {
		return fmt.Errorf("activeProfile %q does not exist", doc.ActiveProfile)
	}
	doc.Preferences["activeProfile"] = doc.ActiveProfile
	if err := validatePreferenceMap(appPreferenceFields, doc.Preferences); err != nil {
		return fmt.Errorf("preferences: %w", err)
	}
	for module, prefs := range doc.ModulePreferences {
		fields, ok := modulePreferenceFields[module]
		if !ok {
			return fmt.Errorf("unsupported module preferences %q", module)
		}
		if err := validatePreferenceMap(fields, prefs); err != nil {
			return fmt.Errorf("%s preferences: %w", module, err)
		}
	}

	services, _, err := normalizeServiceInstances(doc.ServiceInstances, profiles)
	if err != nil {
		return err
	}
	doc.ServiceInstances = services
	if err := normalizeIndexers(doc.Indexers); err != nil {
		return err
	}
	if err := normalizeExternalModules(doc.ExternalModules); err != nil {
		return err
	}
	if err := validateUniqueStrings("dismissed banner", doc.DismissedBanners); err != nil {
		return err
	}
	for _, key := range doc.DismissedBanners {
		if strings.TrimSpace(key) == "" {
			return errors.New("dismissed banner key is required")
		}
	}
	return nil
}

func normalizeProfiles(profiles []profileRecord) (map[string]bool, error) {
	if len(profiles) == 0 {
		return nil, errors.New("at least one profile is required")
	}
	seen := map[string]bool{}
	for i := range profiles {
		profiles[i].ID = strings.TrimSpace(profiles[i].ID)
		profiles[i].DisplayName = strings.TrimSpace(profiles[i].DisplayName)
		if err := validateProfile(profiles[i].ID); err != nil {
			return nil, fmt.Errorf("profile %q: %w", profiles[i].ID, err)
		}
		if seen[profiles[i].ID] {
			return nil, fmt.Errorf("duplicate profile id %q", profiles[i].ID)
		}
		if profiles[i].DisplayName == "" {
			profiles[i].DisplayName = profiles[i].ID
		}
		seen[profiles[i].ID] = true
	}
	return seen, nil
}

func normalizeServiceInstances(services []serviceConfig, profiles map[string]bool) ([]serviceConfig, map[string]bool, error) {
	seen := map[string]bool{}
	serviceProfiles := map[string]bool{}
	normalized := make([]serviceConfig, 0, len(services))
	for i := range services {
		service := services[i]
		service.Service = strings.TrimSpace(service.Service)
		service.Profile = strings.TrimSpace(service.Profile)
		service.InstanceID = strings.TrimSpace(service.InstanceID)
		service.DisplayName = strings.TrimSpace(service.DisplayName)
		service.ConnectionMode = strings.TrimSpace(service.ConnectionMode)
		service.UpstreamURL = strings.TrimSpace(service.UpstreamURL)
		if service.Profile == "" {
			service.Profile = defaultProfileID
		}
		if err := validateService(service.Service); err != nil {
			return nil, nil, fmt.Errorf("service instance %d: %w", i+1, err)
		}
		if err := validateProfile(service.Profile); err != nil {
			return nil, nil, fmt.Errorf("service instance %d profile: %w", i+1, err)
		}
		if profiles != nil && !profiles[service.Profile] {
			return nil, nil, fmt.Errorf("service instance %d profile %q does not exist", i+1, service.Profile)
		}
		if err := validateInstanceID(service.InstanceID); err != nil {
			return nil, nil, fmt.Errorf("service instance %d id: %w", i+1, err)
		}
		if service.DisplayName == "" {
			service.DisplayName = service.Service
		}
		if service.ConnectionMode == "" {
			service.ConnectionMode = "gateway"
		}
		if service.UpstreamURL != "" {
			upstream, err := validateUpstream(service.UpstreamURL)
			if err != nil {
				return nil, nil, fmt.Errorf("service instance %d upstreamUrl: %w", i+1, err)
			}
			service.UpstreamURL = upstream
		}
		if service.Headers == nil {
			service.Headers = map[string]string{}
		}
		if service.Preferences == nil {
			service.Preferences = map[string]any{}
		}
		key := service.Profile + "\x00" + service.Service + "\x00" + service.InstanceID
		if seen[key] {
			return nil, nil, fmt.Errorf("duplicate service instance %s/%s/%s", service.Profile, service.Service, service.InstanceID)
		}
		seen[key] = true
		serviceProfiles[service.Profile] = true
		normalized = append(normalized, service)
	}
	return normalized, serviceProfiles, nil
}

func normalizeIndexers(indexers []indexerRecord) error {
	seen := map[int]bool{}
	for i := range indexers {
		indexers[i].DisplayName = strings.TrimSpace(indexers[i].DisplayName)
		indexers[i].Host = strings.TrimSpace(indexers[i].Host)
		if indexers[i].ID <= 0 {
			return fmt.Errorf("indexer %d id is required", i+1)
		}
		if seen[indexers[i].ID] {
			return fmt.Errorf("duplicate indexer id %d", indexers[i].ID)
		}
		if indexers[i].DisplayName == "" {
			return fmt.Errorf("indexer %d displayName is required", i+1)
		}
		host, err := validateUpstream(indexers[i].Host)
		if err != nil {
			return fmt.Errorf("indexer %d host: %w", i+1, err)
		}
		indexers[i].Host = host
		if indexers[i].Headers == nil {
			indexers[i].Headers = map[string]string{}
		}
		seen[indexers[i].ID] = true
	}
	return nil
}

func normalizeExternalModules(modules []externalModuleRecord) error {
	seen := map[int]bool{}
	for i := range modules {
		modules[i].DisplayName = strings.TrimSpace(modules[i].DisplayName)
		modules[i].Host = strings.TrimSpace(modules[i].Host)
		if modules[i].ID <= 0 {
			return fmt.Errorf("external module %d id is required", i+1)
		}
		if seen[modules[i].ID] {
			return fmt.Errorf("duplicate external module id %d", modules[i].ID)
		}
		if modules[i].DisplayName == "" {
			return fmt.Errorf("external module %d displayName is required", i+1)
		}
		if modules[i].Host == "" {
			return fmt.Errorf("external module %d host is required", i+1)
		}
		if !strings.HasPrefix(modules[i].Host, "/") {
			host, err := validateUpstream(modules[i].Host)
			if err != nil {
				return fmt.Errorf("external module %d host: %w", i+1, err)
			}
			modules[i].Host = host
		}
		seen[modules[i].ID] = true
	}
	return nil
}

func validatePreferenceMap(fields []preferenceField, prefs map[string]any) error {
	fieldMap := map[string]preferenceField{}
	for _, field := range fields {
		fieldMap[field.JSONName] = field
	}
	for key, value := range prefs {
		field, ok := fieldMap[key]
		if !ok {
			return fmt.Errorf("unknown preference %q", key)
		}
		if _, err := preferenceValue(field, value); err != nil {
			return fmt.Errorf("%s: %w", key, err)
		}
	}
	return nil
}

func validateUniqueStrings(kind string, values []string) error {
	seen := map[string]bool{}
	for _, value := range values {
		if seen[value] {
			return fmt.Errorf("duplicate %s %q", kind, value)
		}
		seen[value] = true
	}
	return nil
}

func (doc configDocument) profileIDSet() map[string]bool {
	ids := map[string]bool{}
	for _, profile := range doc.Profiles {
		ids[profile.ID] = true
	}
	return ids
}

func upsertProfilesTx(ctx context.Context, tx *sql.Tx, profiles []profileRecord, now string) error {
	for _, profile := range profiles {
		if _, err := tx.ExecContext(ctx, `
INSERT INTO profiles (id, display_name, sort_order, created_at, updated_at)
VALUES (?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  display_name = excluded.display_name,
  sort_order = excluded.sort_order,
  updated_at = excluded.updated_at;`, profile.ID, profile.DisplayName, profile.SortOrder, now, now); err != nil {
			return err
		}
	}
	return nil
}

func resetPreferencesTx(ctx context.Context, tx *sql.Tx, activeProfile, now string) error {
	if _, err := tx.ExecContext(ctx, `DELETE FROM app_preferences;`); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `
INSERT INTO app_preferences (id, active_profile, created_at, updated_at)
VALUES (1, ?, ?, ?);`, activeProfile, now, now); err != nil {
		return err
	}
	for _, table := range modulePreferenceTables {
		if _, err := tx.ExecContext(ctx, fmt.Sprintf(`DELETE FROM %s;`, table)); err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, fmt.Sprintf(`
INSERT INTO %s (id, created_at, updated_at)
VALUES (1, ?, ?);`, table), now, now); err != nil {
			return err
		}
	}
	return nil
}

func updatePreferencesTx(ctx context.Context, tx *sql.Tx, table string, fields []preferenceField, patch map[string]any) error {
	if len(patch) == 0 {
		return nil
	}
	fieldMap := map[string]preferenceField{}
	for _, field := range fields {
		fieldMap[field.JSONName] = field
	}
	sets := []string{}
	args := []any{}
	for key, value := range patch {
		field, ok := fieldMap[key]
		if !ok {
			return fmt.Errorf("unknown preference %q", key)
		}
		converted, err := preferenceValue(field, value)
		if err != nil {
			return fmt.Errorf("%s: %w", key, err)
		}
		sets = append(sets, field.Column+" = ?")
		args = append(args, converted)
	}
	sets = append(sets, "updated_at = ?")
	args = append(args, nowText(), 1)
	query := fmt.Sprintf("UPDATE %s SET %s WHERE id = ?;", table, strings.Join(sets, ", "))
	_, err := tx.ExecContext(ctx, query, args...)
	return err
}

func deleteProfilesNotInTx(ctx context.Context, tx *sql.Tx, keep map[string]bool) error {
	rows, err := tx.QueryContext(ctx, `SELECT id FROM profiles;`)
	if err != nil {
		return err
	}
	defer rows.Close()
	var remove []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return err
		}
		if !keep[id] {
			remove = append(remove, id)
		}
	}
	if err := rows.Err(); err != nil {
		return err
	}
	for _, id := range remove {
		if _, err := tx.ExecContext(ctx, `DELETE FROM profiles WHERE id = ?;`, id); err != nil {
			return err
		}
	}
	return nil
}

func insertServiceTx(ctx context.Context, tx *sql.Tx, cfg serviceConfig, now string) error {
	headersJSON, err := marshalHeaders(cfg.Headers)
	if err != nil {
		return err
	}
	preferencesJSON, err := marshalPreferences(cfg.Preferences)
	if err != nil {
		return err
	}
	_, err = tx.ExecContext(ctx, `
INSERT INTO service_instances (
  profile_id, service, instance_id, display_name, enabled, sort_order, connection_mode, upstream_url, api_key, username, password, headers_json, preferences_json, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);`,
		cfg.Profile,
		cfg.Service,
		cfg.InstanceID,
		cfg.DisplayName,
		cfg.Enabled,
		cfg.SortOrder,
		cfg.ConnectionMode,
		cfg.UpstreamURL,
		cfg.APIKey,
		cfg.Username,
		cfg.Password,
		headersJSON,
		preferencesJSON,
		now,
		now,
	)
	return err
}

func insertIndexerTx(ctx context.Context, tx *sql.Tx, indexer indexerRecord, now string) error {
	headersJSON, err := marshalHeaders(indexer.Headers)
	if err != nil {
		return err
	}
	_, err = tx.ExecContext(ctx, `
INSERT INTO indexers (id, display_name, host, api_key, headers_json, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?);`, indexer.ID, indexer.DisplayName, indexer.Host, indexer.APIKey, headersJSON, now, now)
	return err
}

func insertExternalModuleTx(ctx context.Context, tx *sql.Tx, module externalModuleRecord, now string) error {
	_, err := tx.ExecContext(ctx, `
INSERT INTO external_modules (id, display_name, host, created_at, updated_at)
VALUES (?, ?, ?, ?, ?);`, module.ID, module.DisplayName, module.Host, now, now)
	return err
}
