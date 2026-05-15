package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"sort"
	"strings"
)

type profileRecord struct {
	ID          string `json:"id"`
	DisplayName string `json:"displayName"`
	SortOrder   int    `json:"sortOrder"`
}

type indexerRecord struct {
	ID          int               `json:"id"`
	DisplayName string            `json:"displayName"`
	Host        string            `json:"host"`
	APIKey      string            `json:"apiKey,omitempty"`
	Headers     map[string]string `json:"headers,omitempty"`
}

type externalModuleRecord struct {
	ID          int    `json:"id"`
	DisplayName string `json:"displayName"`
	Host        string `json:"host"`
}

type logRecord struct {
	ID         int      `json:"id"`
	Timestamp  int64    `json:"timestamp"`
	Type       string   `json:"type"`
	ClassName  string   `json:"className,omitempty"`
	MethodName string   `json:"methodName,omitempty"`
	Message    string   `json:"message"`
	Error      string   `json:"error,omitempty"`
	StackTrace []string `json:"stackTrace,omitempty"`
}

type stateResponse struct {
	Gateway            bool                      `json:"gateway"`
	Version            string                    `json:"version"`
	Services           []string                  `json:"services"`
	ActiveProfile      string                    `json:"activeProfile"`
	Profiles           []profileRecord           `json:"profiles"`
	ServiceConnections []serviceResponse         `json:"serviceConnections"`
	Preferences        map[string]any            `json:"preferences"`
	ModulePreferences  map[string]map[string]any `json:"modulePreferences"`
	Indexers           []indexerRecord           `json:"indexers"`
	ExternalModules    []externalModuleRecord    `json:"externalModules"`
	DismissedBanners   []string                  `json:"dismissedBanners"`
	Logs               []logRecord               `json:"logs"`
}

type preferenceField struct {
	JSONName string
	Column   string
	Kind     string
}

const (
	prefBool   = "bool"
	prefInt    = "int"
	prefString = "string"
	prefJSON   = "json"
)

var appPreferenceFields = []preferenceField{
	{"activeProfile", "active_profile", prefString},
	{"bootModule", "boot_module", prefString},
	{"firstBoot", "first_boot", prefBool},
	{"androidBackOpensDrawer", "android_back_opens_drawer", prefBool},
	{"drawerAutomaticManage", "drawer_automatic_manage", prefBool},
	{"drawerManualOrder", "drawer_manual_order_json", prefJSON},
	{"networkingTlsValidation", "networking_tls_validation", prefBool},
	{"themeAmoled", "theme_amoled", prefBool},
	{"themeAmoledBorder", "theme_amoled_border", prefBool},
	{"themeImageBackgroundOpacity", "theme_image_background_opacity", prefInt},
	{"quickActionsLidarr", "quick_actions_lidarr", prefBool},
	{"quickActionsRadarr", "quick_actions_radarr", prefBool},
	{"quickActionsSonarr", "quick_actions_sonarr", prefBool},
	{"quickActionsNzbget", "quick_actions_nzbget", prefBool},
	{"quickActionsSabnzbd", "quick_actions_sabnzbd", prefBool},
	{"quickActionsOverseerr", "quick_actions_overseerr", prefBool},
	{"quickActionsTautulli", "quick_actions_tautulli", prefBool},
	{"quickActionsSearch", "quick_actions_search", prefBool},
	{"use24HourTime", "use_24_hour_time", prefBool},
	{"enableInAppNotifications", "enable_in_app_notifications", prefBool},
	{"changelogLastBuildVersion", "changelog_last_build_version", prefInt},
	{"searchHideXxx", "search_hide_xxx", prefBool},
	{"searchShowLinks", "search_show_links", prefBool},
	{"dashboardNavigationIndex", "dashboard_navigation_index", prefInt},
	{"dashboardCalendarStartingDay", "dashboard_calendar_starting_day", prefString},
	{"dashboardCalendarStartingSize", "dashboard_calendar_starting_size", prefString},
	{"dashboardCalendarStartingType", "dashboard_calendar_starting_type", prefString},
	{"dashboardCalendarEnableLidarr", "dashboard_calendar_enable_lidarr", prefBool},
	{"dashboardCalendarEnableRadarr", "dashboard_calendar_enable_radarr", prefBool},
	{"dashboardCalendarEnableSonarr", "dashboard_calendar_enable_sonarr", prefBool},
	{"dashboardCalendarDaysPast", "dashboard_calendar_days_past", prefInt},
	{"dashboardCalendarDaysFuture", "dashboard_calendar_days_future", prefInt},
}

var modulePreferenceTables = map[string]string{
	serviceRadarr:   "radarr_preferences",
	serviceSonarr:   "sonarr_preferences",
	serviceLidarr:   "lidarr_preferences",
	serviceNZBGet:   "nzbget_preferences",
	serviceSABnzbd:  "sabnzbd_preferences",
	serviceTautulli: "tautulli_preferences",
}

var modulePreferenceFields = map[string][]preferenceField{
	serviceRadarr: {
		{"navigationIndex", "navigation_index", prefInt},
		{"navigationIndexMovieDetails", "navigation_index_movie_details", prefInt},
		{"navigationIndexAddMovie", "navigation_index_add_movie", prefInt},
		{"navigationIndexSystemStatus", "navigation_index_system_status", prefInt},
		{"defaultViewMovies", "default_view_movies", prefString},
		{"defaultSortingMovies", "default_sorting_movies", prefString},
		{"defaultSortingMoviesAscending", "default_sorting_movies_ascending", prefBool},
		{"defaultFilteringMovies", "default_filtering_movies", prefString},
		{"defaultSortingReleases", "default_sorting_releases", prefString},
		{"defaultSortingReleasesAscending", "default_sorting_releases_ascending", prefBool},
		{"defaultFilteringReleases", "default_filtering_releases", prefString},
		{"addMovieDefaultMonitoredState", "add_movie_default_monitored_state", prefBool},
		{"addMovieDefaultRootFolderId", "add_movie_default_root_folder_id", prefInt},
		{"addMovieDefaultQualityProfileId", "add_movie_default_quality_profile_id", prefInt},
		{"addMovieDefaultMinimumAvailabilityId", "add_movie_default_minimum_availability_id", prefString},
		{"addMovieDefaultTags", "add_movie_default_tags_json", prefJSON},
		{"addMovieSearchForMissing", "add_movie_search_for_missing", prefBool},
		{"addDiscoverUseSuggestions", "add_discover_use_suggestions", prefBool},
		{"manualImportDefaultMode", "manual_import_default_mode", prefString},
		{"queuePageSize", "queue_page_size", prefInt},
		{"queueRefreshRate", "queue_refresh_rate", prefInt},
		{"queueBlacklist", "queue_blacklist", prefBool},
		{"queueRemoveFromClient", "queue_remove_from_client", prefBool},
		{"removeMovieImportList", "remove_movie_import_list", prefBool},
		{"removeMovieDeleteFiles", "remove_movie_delete_files", prefBool},
		{"contentPageSize", "content_page_size", prefInt},
	},
	serviceSonarr: {
		{"navigationIndex", "navigation_index", prefInt},
		{"navigationIndexSeriesDetails", "navigation_index_series_details", prefInt},
		{"navigationIndexSeasonDetails", "navigation_index_season_details", prefInt},
		{"addSeriesSearchForMissing", "add_series_search_for_missing", prefBool},
		{"addSeriesSearchForCutoffUnmet", "add_series_search_for_cutoff_unmet", prefBool},
		{"addSeriesDefaultMonitored", "add_series_default_monitored", prefBool},
		{"addSeriesDefaultUseSeasonFolders", "add_series_default_use_season_folders", prefBool},
		{"addSeriesDefaultSeriesType", "add_series_default_series_type", prefString},
		{"addSeriesDefaultMonitorType", "add_series_default_monitor_type", prefString},
		{"addSeriesDefaultLanguageProfile", "add_series_default_language_profile", prefInt},
		{"addSeriesDefaultQualityProfile", "add_series_default_quality_profile", prefInt},
		{"addSeriesDefaultRootFolder", "add_series_default_root_folder", prefInt},
		{"addSeriesDefaultTags", "add_series_default_tags_json", prefJSON},
		{"defaultViewSeries", "default_view_series", prefString},
		{"defaultFilteringSeries", "default_filtering_series", prefString},
		{"defaultFilteringReleases", "default_filtering_releases", prefString},
		{"defaultSortingSeries", "default_sorting_series", prefString},
		{"defaultSortingReleases", "default_sorting_releases", prefString},
		{"defaultSortingSeriesAscending", "default_sorting_series_ascending", prefBool},
		{"defaultSortingReleasesAscending", "default_sorting_releases_ascending", prefBool},
		{"removeSeriesDeleteFiles", "remove_series_delete_files", prefBool},
		{"removeSeriesExclusionList", "remove_series_exclusion_list", prefBool},
		{"upcomingFutureDays", "upcoming_future_days", prefInt},
		{"queuePageSize", "queue_page_size", prefInt},
		{"queueRefreshRate", "queue_refresh_rate", prefInt},
		{"queueRemoveDownloadClient", "queue_remove_download_client", prefBool},
		{"queueAddBlocklist", "queue_add_blocklist", prefBool},
		{"contentPageSize", "content_page_size", prefInt},
	},
	serviceLidarr: {
		{"navigationIndex", "navigation_index", prefInt},
		{"addMonitoredStatus", "add_monitored_status", prefString},
		{"addArtistSearchForMissing", "add_artist_search_for_missing", prefBool},
		{"addAlbumFolders", "add_album_folders", prefBool},
		{"addQualityProfile", "add_quality_profile_json", prefJSON},
		{"addMetadataProfile", "add_metadata_profile_json", prefJSON},
		{"addRootFolder", "add_root_folder_json", prefJSON},
	},
	serviceNZBGet: {
		{"navigationIndex", "navigation_index", prefInt},
	},
	serviceSABnzbd: {
		{"navigationIndex", "navigation_index", prefInt},
	},
	serviceTautulli: {
		{"navigationIndex", "navigation_index", prefInt},
		{"navigationIndexGraphs", "navigation_index_graphs", prefInt},
		{"navigationIndexLibrariesDetails", "navigation_index_libraries_details", prefInt},
		{"navigationIndexMediaDetails", "navigation_index_media_details", prefInt},
		{"navigationIndexUserDetails", "navigation_index_user_details", prefInt},
		{"refreshRate", "refresh_rate", prefInt},
		{"contentLoadLength", "content_load_length", prefInt},
		{"statisticsStatsCount", "statistics_stats_count", prefInt},
		{"terminationMessage", "termination_message", prefString},
		{"graphsDays", "graphs_days", prefInt},
		{"graphsLinechartDays", "graphs_linechart_days", prefInt},
		{"graphsMonths", "graphs_months", prefInt},
	},
}

func (a *app) state(w http.ResponseWriter, r *http.Request) {
	state, err := a.store.stateSnapshot(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, state)
}

func (s *store) stateSnapshot(ctx context.Context) (stateResponse, error) {
	profiles, err := s.listProfiles(ctx)
	if err != nil {
		return stateResponse{}, err
	}
	services, err := s.listServices(ctx)
	if err != nil {
		return stateResponse{}, err
	}
	appPrefs, err := s.preferenceMap(ctx, "app_preferences", appPreferenceFields)
	if err != nil {
		return stateResponse{}, err
	}
	modulePrefs := map[string]map[string]any{}
	for service, table := range modulePreferenceTables {
		prefs, err := s.preferenceMap(ctx, table, modulePreferenceFields[service])
		if err != nil {
			return stateResponse{}, err
		}
		modulePrefs[service] = prefs
	}
	indexers, err := s.listIndexers(ctx, false)
	if err != nil {
		return stateResponse{}, err
	}
	externalModules, err := s.listExternalModules(ctx)
	if err != nil {
		return stateResponse{}, err
	}
	banners, err := s.listDismissedBanners(ctx)
	if err != nil {
		return stateResponse{}, err
	}
	logs, err := s.listLogs(ctx, 50)
	if err != nil {
		return stateResponse{}, err
	}
	redacted := make([]serviceResponse, 0, len(services))
	for _, service := range services {
		redacted = append(redacted, service.redacted())
	}
	active, _ := appPrefs["activeProfile"].(string)
	return stateResponse{
		Gateway:            true,
		Version:            "2",
		Services:           supportedServices,
		ActiveProfile:      active,
		Profiles:           profiles,
		ServiceConnections: redacted,
		Preferences:        appPrefs,
		ModulePreferences:  modulePrefs,
		Indexers:           indexers,
		ExternalModules:    externalModules,
		DismissedBanners:   banners,
		Logs:               logs,
	}, nil
}

func (s *store) listProfiles(ctx context.Context) ([]profileRecord, error) {
	rows, err := s.db.QueryContext(ctx, `
SELECT id, display_name, sort_order
FROM profiles
ORDER BY sort_order, lower(display_name), id;`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var profiles []profileRecord
	for rows.Next() {
		var profile profileRecord
		if err := rows.Scan(&profile.ID, &profile.DisplayName, &profile.SortOrder); err != nil {
			return nil, err
		}
		profiles = append(profiles, profile)
	}
	return profiles, rows.Err()
}

func (a *app) createProfile(w http.ResponseWriter, r *http.Request) {
	var request struct {
		ID          string `json:"id"`
		DisplayName string `json:"displayName"`
	}
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "bad_json", err.Error())
		return
	}
	id := request.ID
	if id == "" {
		id = request.DisplayName
	}
	id = sanitizeProfile(id)
	if err := validateProfile(id); err != nil {
		writeError(w, http.StatusBadRequest, "bad_profile", err.Error())
		return
	}
	if request.DisplayName == "" {
		request.DisplayName = id
	}
	profile, err := a.store.createProfile(r.Context(), id, request.DisplayName)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, profile)
}

func (s *store) createProfile(ctx context.Context, id, displayName string) (profileRecord, error) {
	now := nowText()
	_, err := s.db.ExecContext(ctx, `
INSERT INTO profiles (id, display_name, sort_order, created_at, updated_at)
VALUES (?, ?, (SELECT COALESCE(MAX(sort_order), -1) + 1 FROM profiles), ?, ?);`, id, displayName, now, now)
	if err != nil {
		return profileRecord{}, err
	}
	return profileRecord{ID: id, DisplayName: displayName}, nil
}

func (a *app) patchProfile(w http.ResponseWriter, r *http.Request) {
	profile := r.PathValue("profile")
	if err := validateProfile(profile); err != nil {
		writeError(w, http.StatusBadRequest, "bad_profile", err.Error())
		return
	}
	var request struct {
		DisplayName *string `json:"displayName"`
		SortOrder   *int    `json:"sortOrder"`
		Active      *bool   `json:"active"`
	}
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "bad_json", err.Error())
		return
	}
	updated, err := a.store.patchProfile(r.Context(), profile, request.DisplayName, request.SortOrder, request.Active)
	if errors.Is(err, errNotFound) {
		writeError(w, http.StatusNotFound, "profile_not_found", "Profile was not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, updated)
}

func (s *store) patchProfile(ctx context.Context, id string, displayName *string, sortOrder *int, active *bool) (profileRecord, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return profileRecord{}, err
	}
	defer tx.Rollback()
	var exists int
	if err := tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM profiles WHERE id = ?;`, id).Scan(&exists); err != nil {
		return profileRecord{}, err
	}
	if exists == 0 {
		return profileRecord{}, errNotFound
	}
	if displayName != nil {
		if _, err := tx.ExecContext(ctx, `UPDATE profiles SET display_name = ?, updated_at = ? WHERE id = ?;`, *displayName, nowText(), id); err != nil {
			return profileRecord{}, err
		}
	}
	if sortOrder != nil {
		if _, err := tx.ExecContext(ctx, `UPDATE profiles SET sort_order = ?, updated_at = ? WHERE id = ?;`, *sortOrder, nowText(), id); err != nil {
			return profileRecord{}, err
		}
	}
	if active != nil && *active {
		if _, err := tx.ExecContext(ctx, `UPDATE app_preferences SET active_profile = ?, updated_at = ? WHERE id = 1;`, id, nowText()); err != nil {
			return profileRecord{}, err
		}
	}
	var profile profileRecord
	if err := tx.QueryRowContext(ctx, `SELECT id, display_name, sort_order FROM profiles WHERE id = ?;`, id).Scan(&profile.ID, &profile.DisplayName, &profile.SortOrder); err != nil {
		return profileRecord{}, err
	}
	return profile, tx.Commit()
}

func (a *app) deleteProfile(w http.ResponseWriter, r *http.Request) {
	profile := r.PathValue("profile")
	if profile == defaultProfileID {
		writeError(w, http.StatusBadRequest, "default_profile", "The default profile cannot be deleted")
		return
	}
	if err := validateProfile(profile); err != nil {
		writeError(w, http.StatusBadRequest, "bad_profile", err.Error())
		return
	}
	if err := a.store.deleteProfile(r.Context(), profile); errors.Is(err, errNotFound) {
		writeError(w, http.StatusNotFound, "profile_not_found", "Profile was not found")
	} else if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
	} else {
		w.WriteHeader(http.StatusNoContent)
	}
}

func (s *store) deleteProfile(ctx context.Context, id string) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.ExecContext(ctx, `UPDATE app_preferences SET active_profile = ?, updated_at = ? WHERE active_profile = ?;`, defaultProfileID, nowText(), id); err != nil {
		return err
	}
	result, err := tx.ExecContext(ctx, `DELETE FROM profiles WHERE id = ?;`, id)
	if err != nil {
		return err
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if affected == 0 {
		return errNotFound
	}
	return tx.Commit()
}

func (a *app) putProfileService(w http.ResponseWriter, r *http.Request) {
	service, profile, ok := serviceRouteValues(w, r)
	if !ok {
		return
	}
	a.putServiceFor(w, r, service, profile)
}

func (a *app) deleteProfileService(w http.ResponseWriter, r *http.Request) {
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

func (a *app) patchAppPreferences(w http.ResponseWriter, r *http.Request) {
	var patch map[string]any
	if err := json.NewDecoder(r.Body).Decode(&patch); err != nil {
		writeError(w, http.StatusBadRequest, "bad_json", err.Error())
		return
	}
	prefs, err := a.store.patchPreferences(r.Context(), "app_preferences", appPreferenceFields, patch)
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_preferences", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, prefs)
}

func (a *app) patchModulePreferences(w http.ResponseWriter, r *http.Request) {
	module := r.PathValue("module")
	table, ok := modulePreferenceTables[module]
	if !ok {
		writeError(w, http.StatusNotFound, "unsupported_module", "Unsupported module preferences")
		return
	}
	var patch map[string]any
	if err := json.NewDecoder(r.Body).Decode(&patch); err != nil {
		writeError(w, http.StatusBadRequest, "bad_json", err.Error())
		return
	}
	prefs, err := a.store.patchPreferences(r.Context(), table, modulePreferenceFields[module], patch)
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_preferences", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, prefs)
}

func (s *store) patchPreferences(ctx context.Context, table string, fields []preferenceField, patch map[string]any) (map[string]any, error) {
	fieldMap := map[string]preferenceField{}
	for _, field := range fields {
		fieldMap[field.JSONName] = field
	}
	sets := []string{}
	args := []any{}
	for key, value := range patch {
		field, ok := fieldMap[key]
		if !ok {
			return nil, fmt.Errorf("unknown preference %q", key)
		}
		converted, err := preferenceValue(field, value)
		if err != nil {
			return nil, fmt.Errorf("%s: %w", key, err)
		}
		sets = append(sets, field.Column+" = ?")
		args = append(args, converted)
	}
	if len(sets) > 0 {
		sets = append(sets, "updated_at = ?")
		args = append(args, nowText(), 1)
		query := fmt.Sprintf("UPDATE %s SET %s WHERE id = ?;", table, strings.Join(sets, ", "))
		if _, err := s.db.ExecContext(ctx, query, args...); err != nil {
			return nil, err
		}
	}
	return s.preferenceMap(ctx, table, fields)
}

func preferenceValue(field preferenceField, value any) (any, error) {
	if value == nil {
		if field.Kind == prefInt {
			return nil, nil
		}
		if field.Kind == prefJSON {
			return "null", nil
		}
		return nil, errors.New("null is not allowed")
	}
	switch field.Kind {
	case prefBool:
		v, ok := value.(bool)
		if !ok {
			return nil, errors.New("must be a boolean")
		}
		if v {
			return 1, nil
		}
		return 0, nil
	case prefInt:
		switch v := value.(type) {
		case float64:
			if v != float64(int(v)) {
				return nil, errors.New("must be an integer")
			}
			return int(v), nil
		case int:
			return v, nil
		default:
			return nil, errors.New("must be an integer")
		}
	case prefString:
		v, ok := value.(string)
		if !ok {
			return nil, errors.New("must be a string")
		}
		if field.JSONName == "activeProfile" {
			if err := validateProfile(v); err != nil {
				return nil, err
			}
		}
		return v, nil
	case prefJSON:
		data, err := json.Marshal(value)
		if err != nil {
			return nil, err
		}
		return string(data), nil
	default:
		return nil, errors.New("unsupported preference type")
	}
}

func (s *store) preferenceMap(ctx context.Context, table string, fields []preferenceField) (map[string]any, error) {
	columns := make([]string, len(fields))
	for i, field := range fields {
		columns[i] = field.Column
	}
	query := fmt.Sprintf("SELECT %s FROM %s WHERE id = 1;", strings.Join(columns, ", "), table)
	raw := make([]any, len(fields))
	dest := make([]any, len(fields))
	for i := range raw {
		dest[i] = &raw[i]
	}
	if err := s.db.QueryRowContext(ctx, query).Scan(dest...); err != nil {
		return nil, err
	}
	result := map[string]any{}
	for i, field := range fields {
		result[field.JSONName] = preferenceOutput(field, raw[i])
	}
	return result, nil
}

func preferenceOutput(field preferenceField, value any) any {
	if value == nil {
		return nil
	}
	switch field.Kind {
	case prefBool:
		return asInt(value) != 0
	case prefInt:
		return asInt(value)
	case prefString:
		return asString(value)
	case prefJSON:
		var out any
		if err := json.Unmarshal([]byte(asString(value)), &out); err != nil {
			return nil
		}
		return out
	default:
		return value
	}
}

func asInt(value any) int {
	switch v := value.(type) {
	case int64:
		return int(v)
	case int:
		return v
	case []byte:
		var out int
		_, _ = fmt.Sscanf(string(v), "%d", &out)
		return out
	default:
		return 0
	}
}

func asString(value any) string {
	switch v := value.(type) {
	case string:
		return v
	case []byte:
		return string(v)
	default:
		return fmt.Sprint(v)
	}
}

func (a *app) createIndexer(w http.ResponseWriter, r *http.Request) {
	var request indexerRecord
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "bad_json", err.Error())
		return
	}
	created, err := a.store.createIndexer(r.Context(), request)
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_indexer", err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, redactIndexer(created))
}

func (a *app) patchIndexer(w http.ResponseWriter, r *http.Request) {
	id, ok := intRouteValue(w, r, "id")
	if !ok {
		return
	}
	request, err := decodeIndexerPatch(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_json", err.Error())
		return
	}
	existing, err := a.store.getIndexer(r.Context(), id, true)
	if errors.Is(err, errNotFound) {
		writeError(w, http.StatusNotFound, "indexer_not_found", "Indexer was not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	record := request.apply(&existing)
	updated, err := a.store.updateIndexer(r.Context(), record)
	if errors.Is(err, errNotFound) {
		writeError(w, http.StatusNotFound, "indexer_not_found", "Indexer was not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_indexer", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, redactIndexer(updated))
}

func (a *app) deleteIndexer(w http.ResponseWriter, r *http.Request) {
	id, ok := intRouteValue(w, r, "id")
	if !ok {
		return
	}
	if err := a.store.deleteByID(r.Context(), "indexers", id); errors.Is(err, errNotFound) {
		writeError(w, http.StatusNotFound, "indexer_not_found", "Indexer was not found")
	} else if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
	} else {
		w.WriteHeader(http.StatusNoContent)
	}
}

func (s *store) createIndexer(ctx context.Context, indexer indexerRecord) (indexerRecord, error) {
	if indexer.DisplayName == "" || indexer.Host == "" {
		return indexerRecord{}, errors.New("displayName and host are required")
	}
	headersJSON, err := marshalHeaders(indexer.Headers)
	if err != nil {
		return indexerRecord{}, err
	}
	now := nowText()
	result, err := s.db.ExecContext(ctx, `
INSERT INTO indexers (display_name, host, api_key, headers_json, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?);`, indexer.DisplayName, indexer.Host, indexer.APIKey, headersJSON, now, now)
	if err != nil {
		return indexerRecord{}, err
	}
	id, err := result.LastInsertId()
	if err != nil {
		return indexerRecord{}, err
	}
	indexer.ID = int(id)
	if indexer.Headers == nil {
		indexer.Headers = map[string]string{}
	}
	return indexer, nil
}

func (s *store) updateIndexer(ctx context.Context, indexer indexerRecord) (indexerRecord, error) {
	if indexer.DisplayName == "" || indexer.Host == "" {
		return indexerRecord{}, errors.New("displayName and host are required")
	}
	headersJSON, err := marshalHeaders(indexer.Headers)
	if err != nil {
		return indexerRecord{}, err
	}
	result, err := s.db.ExecContext(ctx, `
UPDATE indexers
SET display_name = ?, host = ?, api_key = ?, headers_json = ?, updated_at = ?
WHERE id = ?;`, indexer.DisplayName, indexer.Host, indexer.APIKey, headersJSON, nowText(), indexer.ID)
	if err != nil {
		return indexerRecord{}, err
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return indexerRecord{}, err
	}
	if affected == 0 {
		return indexerRecord{}, errNotFound
	}
	if indexer.Headers == nil {
		indexer.Headers = map[string]string{}
	}
	return indexer, nil
}

type indexerPatch struct {
	DisplayName *string            `json:"displayName"`
	Host        *string            `json:"host"`
	APIKey      *string            `json:"apiKey"`
	Headers     *map[string]string `json:"headers"`
}

func decodeIndexerPatch(r *http.Request) (indexerPatch, error) {
	var patch indexerPatch
	err := json.NewDecoder(r.Body).Decode(&patch)
	return patch, err
}

func (p indexerPatch) apply(indexer *indexerRecord) indexerRecord {
	if p.DisplayName != nil {
		indexer.DisplayName = *p.DisplayName
	}
	if p.Host != nil {
		indexer.Host = *p.Host
	}
	if p.APIKey != nil {
		indexer.APIKey = *p.APIKey
	}
	if p.Headers != nil {
		indexer.Headers = *p.Headers
	}
	return *indexer
}

func redactIndexer(indexer indexerRecord) indexerRecord {
	indexer.APIKey = ""
	indexer.Headers = map[string]string{}
	return indexer
}

func (s *store) getIndexer(ctx context.Context, id int, includeSecrets bool) (indexerRecord, error) {
	var indexer indexerRecord
	var headersJSON string
	err := s.db.QueryRowContext(ctx, `
SELECT id, display_name, host, api_key, headers_json
FROM indexers
WHERE id = ?;`, id).Scan(&indexer.ID, &indexer.DisplayName, &indexer.Host, &indexer.APIKey, &headersJSON)
	if errors.Is(err, sql.ErrNoRows) {
		return indexerRecord{}, errNotFound
	}
	if err != nil {
		return indexerRecord{}, err
	}
	if includeSecrets {
		indexer.Headers = unmarshalHeaders(headersJSON)
	} else {
		indexer.APIKey = ""
		indexer.Headers = map[string]string{}
	}
	return indexer, nil
}

func (s *store) listIndexers(ctx context.Context, includeSecrets bool) ([]indexerRecord, error) {
	rows, err := s.db.QueryContext(ctx, `
SELECT id, display_name, host, api_key, headers_json
FROM indexers
ORDER BY lower(display_name), id;`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var indexers []indexerRecord
	for rows.Next() {
		var indexer indexerRecord
		var headersJSON string
		if err := rows.Scan(&indexer.ID, &indexer.DisplayName, &indexer.Host, &indexer.APIKey, &headersJSON); err != nil {
			return nil, err
		}
		if !includeSecrets {
			indexer.APIKey = ""
			indexer.Headers = map[string]string{}
		} else {
			indexer.Headers = unmarshalHeaders(headersJSON)
		}
		indexers = append(indexers, indexer)
	}
	return indexers, rows.Err()
}

func (a *app) createExternalModule(w http.ResponseWriter, r *http.Request) {
	var request externalModuleRecord
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "bad_json", err.Error())
		return
	}
	created, err := a.store.createExternalModule(r.Context(), request)
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_external_module", err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, created)
}

func (a *app) patchExternalModule(w http.ResponseWriter, r *http.Request) {
	id, ok := intRouteValue(w, r, "id")
	if !ok {
		return
	}
	var request externalModuleRecord
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "bad_json", err.Error())
		return
	}
	request.ID = id
	updated, err := a.store.updateExternalModule(r.Context(), request)
	if errors.Is(err, errNotFound) {
		writeError(w, http.StatusNotFound, "external_module_not_found", "External module was not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_external_module", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, updated)
}

func (a *app) deleteExternalModule(w http.ResponseWriter, r *http.Request) {
	id, ok := intRouteValue(w, r, "id")
	if !ok {
		return
	}
	if err := a.store.deleteByID(r.Context(), "external_modules", id); errors.Is(err, errNotFound) {
		writeError(w, http.StatusNotFound, "external_module_not_found", "External module was not found")
	} else if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
	} else {
		w.WriteHeader(http.StatusNoContent)
	}
}

func (s *store) createExternalModule(ctx context.Context, module externalModuleRecord) (externalModuleRecord, error) {
	if module.DisplayName == "" || module.Host == "" {
		return externalModuleRecord{}, errors.New("displayName and host are required")
	}
	now := nowText()
	result, err := s.db.ExecContext(ctx, `
INSERT INTO external_modules (display_name, host, created_at, updated_at)
VALUES (?, ?, ?, ?);`, module.DisplayName, module.Host, now, now)
	if err != nil {
		return externalModuleRecord{}, err
	}
	id, err := result.LastInsertId()
	if err != nil {
		return externalModuleRecord{}, err
	}
	module.ID = int(id)
	return module, nil
}

func (s *store) updateExternalModule(ctx context.Context, module externalModuleRecord) (externalModuleRecord, error) {
	if module.DisplayName == "" || module.Host == "" {
		return externalModuleRecord{}, errors.New("displayName and host are required")
	}
	result, err := s.db.ExecContext(ctx, `
UPDATE external_modules
SET display_name = ?, host = ?, updated_at = ?
WHERE id = ?;`, module.DisplayName, module.Host, nowText(), module.ID)
	if err != nil {
		return externalModuleRecord{}, err
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return externalModuleRecord{}, err
	}
	if affected == 0 {
		return externalModuleRecord{}, errNotFound
	}
	return module, nil
}

func (s *store) listExternalModules(ctx context.Context) ([]externalModuleRecord, error) {
	rows, err := s.db.QueryContext(ctx, `
SELECT id, display_name, host
FROM external_modules
ORDER BY lower(display_name), id;`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var modules []externalModuleRecord
	for rows.Next() {
		var module externalModuleRecord
		if err := rows.Scan(&module.ID, &module.DisplayName, &module.Host); err != nil {
			return nil, err
		}
		modules = append(modules, module)
	}
	return modules, rows.Err()
}

func (s *store) deleteByID(ctx context.Context, table string, id int) error {
	allowed := map[string]bool{"indexers": true, "external_modules": true}
	if !allowed[table] {
		return errors.New("unsupported table")
	}
	result, err := s.db.ExecContext(ctx, fmt.Sprintf("DELETE FROM %s WHERE id = ?;", table), id)
	if err != nil {
		return err
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if affected == 0 {
		return errNotFound
	}
	return nil
}

func (a *app) dismissBanner(w http.ResponseWriter, r *http.Request) {
	key := r.PathValue("key")
	if key == "" {
		writeError(w, http.StatusBadRequest, "bad_banner", "Banner key is required")
		return
	}
	if err := a.store.dismissBanner(r.Context(), key); err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"key": key})
}

func (a *app) undismissBanner(w http.ResponseWriter, r *http.Request) {
	key := r.PathValue("key")
	if key == "" {
		writeError(w, http.StatusBadRequest, "bad_banner", "Banner key is required")
		return
	}
	_, err := a.store.db.ExecContext(r.Context(), `DELETE FROM dismissed_banners WHERE key = ?;`, key)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *store) dismissBanner(ctx context.Context, key string) error {
	_, err := s.db.ExecContext(ctx, `
INSERT INTO dismissed_banners (key, dismissed_at)
VALUES (?, ?)
ON CONFLICT(key) DO UPDATE SET dismissed_at = excluded.dismissed_at;`, key, nowText())
	return err
}

func (s *store) listDismissedBanners(ctx context.Context) ([]string, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT key FROM dismissed_banners ORDER BY key;`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var keys []string
	for rows.Next() {
		var key string
		if err := rows.Scan(&key); err != nil {
			return nil, err
		}
		keys = append(keys, key)
	}
	return keys, rows.Err()
}

func (a *app) createLog(w http.ResponseWriter, r *http.Request) {
	var request logRecord
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, "bad_json", err.Error())
		return
	}
	created, err := a.store.createLog(r.Context(), request)
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_log", err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, created)
}

func (a *app) clearLogs(w http.ResponseWriter, r *http.Request) {
	if _, err := a.store.db.ExecContext(r.Context(), `DELETE FROM logs;`); err != nil {
		writeError(w, http.StatusInternalServerError, "store_error", err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *store) createLog(ctx context.Context, log logRecord) (logRecord, error) {
	if log.Timestamp == 0 || log.Type == "" || log.Message == "" {
		return logRecord{}, errors.New("timestamp, type, and message are required")
	}
	stackJSON, err := json.Marshal(log.StackTrace)
	if err != nil {
		return logRecord{}, err
	}
	result, err := s.db.ExecContext(ctx, `
INSERT INTO logs (timestamp, type, class_name, method_name, message, error, stack_trace_json, created_at)
VALUES (?, ?, ?, ?, ?, ?, ?, ?);`, log.Timestamp, log.Type, log.ClassName, log.MethodName, log.Message, log.Error, string(stackJSON), nowText())
	if err != nil {
		return logRecord{}, err
	}
	id, err := result.LastInsertId()
	if err != nil {
		return logRecord{}, err
	}
	log.ID = int(id)
	return log, nil
}

func (s *store) listLogs(ctx context.Context, limit int) ([]logRecord, error) {
	rows, err := s.db.QueryContext(ctx, `
SELECT id, timestamp, type, class_name, method_name, message, error, stack_trace_json
FROM logs
ORDER BY timestamp DESC, id DESC
LIMIT ?;`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var logs []logRecord
	for rows.Next() {
		var log logRecord
		var stackJSON string
		if err := rows.Scan(&log.ID, &log.Timestamp, &log.Type, &log.ClassName, &log.MethodName, &log.Message, &log.Error, &stackJSON); err != nil {
			return nil, err
		}
		_ = json.Unmarshal([]byte(stackJSON), &log.StackTrace)
		logs = append(logs, log)
	}
	return logs, rows.Err()
}

func intRouteValue(w http.ResponseWriter, r *http.Request, name string) (int, bool) {
	var id int
	if _, err := fmt.Sscanf(r.PathValue(name), "%d", &id); err != nil || id < 0 {
		writeError(w, http.StatusBadRequest, "bad_id", "Invalid ID")
		return 0, false
	}
	return id, true
}

func sanitizeProfile(value string) string {
	value = strings.TrimSpace(value)
	value = strings.ReplaceAll(value, " ", "_")
	var builder strings.Builder
	for _, r := range value {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '-' || r == '_' || r == '.' {
			builder.WriteRune(r)
		} else {
			builder.WriteRune('_')
		}
	}
	return builder.String()
}

func sortedKeys(values map[string]any) []string {
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}
