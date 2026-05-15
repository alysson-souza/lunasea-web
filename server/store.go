package main

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	_ "modernc.org/sqlite"
)

var errNotFound = errors.New("service config not found")

const defaultProfileID = "default"

type store struct {
	db *sql.DB
}

type migration struct {
	version int
	name    string
	run     func(context.Context, *sql.Tx) error
}

func openStore(path string) (*store, error) {
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	if _, err := db.Exec(`PRAGMA foreign_keys = ON;`); err != nil {
		_ = db.Close()
		return nil, err
	}
	if _, err := db.Exec(`PRAGMA busy_timeout = 5000;`); err != nil {
		_ = db.Close()
		return nil, err
	}
	_, _ = db.Exec(`PRAGMA journal_mode = WAL;`)

	s := &store{db: db}
	if err := s.migrate(context.Background()); err != nil {
		_ = db.Close()
		return nil, err
	}
	return s, nil
}

func (s *store) close() error {
	if s == nil || s.db == nil {
		return nil
	}
	return s.db.Close()
}

func (s *store) migrate(ctx context.Context) error {
	migrations := []migration{
		{version: 1, name: "schemaful app state", run: migrateSchemafulAppState},
		{version: 2, name: "legacy gateway service configs", run: migrateLegacyServiceConfigs},
	}

	if _, err := s.db.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS schema_migrations (
  version INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  applied_at TEXT NOT NULL
) STRICT;`); err != nil {
		return err
	}

	for _, migration := range migrations {
		applied, err := s.migrationApplied(ctx, migration.version)
		if err != nil {
			return err
		}
		if applied {
			continue
		}
		if err := s.applyMigration(ctx, migration); err != nil {
			return err
		}
	}
	return s.bootstrapDefaults(ctx)
}

func (s *store) migrationApplied(ctx context.Context, version int) (bool, error) {
	var count int
	err := s.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM schema_migrations WHERE version = ?;`, version).Scan(&count)
	return count > 0, err
}

func (s *store) applyMigration(ctx context.Context, migration migration) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if err := migration.run(ctx, tx); err != nil {
		return fmt.Errorf("migration %d (%s): %w", migration.version, migration.name, err)
	}
	if _, err := tx.ExecContext(ctx, `
INSERT INTO schema_migrations (version, name, applied_at)
VALUES (?, ?, ?);`, migration.version, migration.name, nowText()); err != nil {
		return err
	}
	return tx.Commit()
}

func migrateSchemafulAppState(ctx context.Context, tx *sql.Tx) error {
	_, err := tx.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS profiles (
  id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS app_preferences (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  active_profile TEXT NOT NULL DEFAULT 'default' REFERENCES profiles(id) ON UPDATE CASCADE,
  boot_module TEXT NOT NULL DEFAULT 'dashboard',
  first_boot INTEGER NOT NULL DEFAULT 1 CHECK (first_boot IN (0, 1)),
  android_back_opens_drawer INTEGER NOT NULL DEFAULT 1 CHECK (android_back_opens_drawer IN (0, 1)),
  drawer_automatic_manage INTEGER NOT NULL DEFAULT 1 CHECK (drawer_automatic_manage IN (0, 1)),
  drawer_manual_order_json TEXT NOT NULL DEFAULT '[]',
  networking_tls_validation INTEGER NOT NULL DEFAULT 0 CHECK (networking_tls_validation IN (0, 1)),
  theme_amoled INTEGER NOT NULL DEFAULT 0 CHECK (theme_amoled IN (0, 1)),
  theme_amoled_border INTEGER NOT NULL DEFAULT 0 CHECK (theme_amoled_border IN (0, 1)),
  theme_image_background_opacity INTEGER NOT NULL DEFAULT 20 CHECK (theme_image_background_opacity BETWEEN 0 AND 100),
  quick_actions_lidarr INTEGER NOT NULL DEFAULT 0 CHECK (quick_actions_lidarr IN (0, 1)),
  quick_actions_radarr INTEGER NOT NULL DEFAULT 0 CHECK (quick_actions_radarr IN (0, 1)),
  quick_actions_sonarr INTEGER NOT NULL DEFAULT 0 CHECK (quick_actions_sonarr IN (0, 1)),
  quick_actions_nzbget INTEGER NOT NULL DEFAULT 0 CHECK (quick_actions_nzbget IN (0, 1)),
  quick_actions_sabnzbd INTEGER NOT NULL DEFAULT 0 CHECK (quick_actions_sabnzbd IN (0, 1)),
  quick_actions_overseerr INTEGER NOT NULL DEFAULT 0 CHECK (quick_actions_overseerr IN (0, 1)),
  quick_actions_tautulli INTEGER NOT NULL DEFAULT 0 CHECK (quick_actions_tautulli IN (0, 1)),
  quick_actions_search INTEGER NOT NULL DEFAULT 0 CHECK (quick_actions_search IN (0, 1)),
  use_24_hour_time INTEGER NOT NULL DEFAULT 0 CHECK (use_24_hour_time IN (0, 1)),
  enable_in_app_notifications INTEGER NOT NULL DEFAULT 1 CHECK (enable_in_app_notifications IN (0, 1)),
  changelog_last_build_version INTEGER NOT NULL DEFAULT 0,
  search_hide_xxx INTEGER NOT NULL DEFAULT 0 CHECK (search_hide_xxx IN (0, 1)),
  search_show_links INTEGER NOT NULL DEFAULT 1 CHECK (search_show_links IN (0, 1)),
  dashboard_navigation_index INTEGER NOT NULL DEFAULT 0,
  dashboard_calendar_starting_day TEXT NOT NULL DEFAULT 'mon',
  dashboard_calendar_starting_size TEXT NOT NULL DEFAULT 'oneweek',
  dashboard_calendar_starting_type TEXT NOT NULL DEFAULT 'calendar',
  dashboard_calendar_enable_lidarr INTEGER NOT NULL DEFAULT 1 CHECK (dashboard_calendar_enable_lidarr IN (0, 1)),
  dashboard_calendar_enable_radarr INTEGER NOT NULL DEFAULT 1 CHECK (dashboard_calendar_enable_radarr IN (0, 1)),
  dashboard_calendar_enable_sonarr INTEGER NOT NULL DEFAULT 1 CHECK (dashboard_calendar_enable_sonarr IN (0, 1)),
  dashboard_calendar_days_past INTEGER NOT NULL DEFAULT 14,
  dashboard_calendar_days_future INTEGER NOT NULL DEFAULT 14,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS service_connections (
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
CREATE INDEX IF NOT EXISTS service_connections_service_idx ON service_connections(service);

CREATE TABLE IF NOT EXISTS radarr_preferences (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  navigation_index INTEGER NOT NULL DEFAULT 0,
  navigation_index_movie_details INTEGER NOT NULL DEFAULT 0,
  navigation_index_add_movie INTEGER NOT NULL DEFAULT 0,
  navigation_index_system_status INTEGER NOT NULL DEFAULT 0,
  default_view_movies TEXT NOT NULL DEFAULT 'BLOCK_VIEW',
  default_sorting_movies TEXT NOT NULL DEFAULT 'abc',
  default_sorting_movies_ascending INTEGER NOT NULL DEFAULT 1 CHECK (default_sorting_movies_ascending IN (0, 1)),
  default_filtering_movies TEXT NOT NULL DEFAULT 'all',
  default_sorting_releases TEXT NOT NULL DEFAULT 'weight',
  default_sorting_releases_ascending INTEGER NOT NULL DEFAULT 1 CHECK (default_sorting_releases_ascending IN (0, 1)),
  default_filtering_releases TEXT NOT NULL DEFAULT 'all',
  add_movie_default_monitored_state INTEGER NOT NULL DEFAULT 1 CHECK (add_movie_default_monitored_state IN (0, 1)),
  add_movie_default_root_folder_id INTEGER,
  add_movie_default_quality_profile_id INTEGER,
  add_movie_default_minimum_availability_id TEXT NOT NULL DEFAULT 'announced',
  add_movie_default_tags_json TEXT NOT NULL DEFAULT '[]',
  add_movie_search_for_missing INTEGER NOT NULL DEFAULT 0 CHECK (add_movie_search_for_missing IN (0, 1)),
  add_discover_use_suggestions INTEGER NOT NULL DEFAULT 1 CHECK (add_discover_use_suggestions IN (0, 1)),
  manual_import_default_mode TEXT NOT NULL DEFAULT 'copy',
  queue_page_size INTEGER NOT NULL DEFAULT 50,
  queue_refresh_rate INTEGER NOT NULL DEFAULT 60,
  queue_blacklist INTEGER NOT NULL DEFAULT 0 CHECK (queue_blacklist IN (0, 1)),
  queue_remove_from_client INTEGER NOT NULL DEFAULT 0 CHECK (queue_remove_from_client IN (0, 1)),
  remove_movie_import_list INTEGER NOT NULL DEFAULT 0 CHECK (remove_movie_import_list IN (0, 1)),
  remove_movie_delete_files INTEGER NOT NULL DEFAULT 0 CHECK (remove_movie_delete_files IN (0, 1)),
  content_page_size INTEGER NOT NULL DEFAULT 10,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS sonarr_preferences (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  navigation_index INTEGER NOT NULL DEFAULT 0,
  navigation_index_series_details INTEGER NOT NULL DEFAULT 0,
  navigation_index_season_details INTEGER NOT NULL DEFAULT 0,
  add_series_search_for_missing INTEGER NOT NULL DEFAULT 0 CHECK (add_series_search_for_missing IN (0, 1)),
  add_series_search_for_cutoff_unmet INTEGER NOT NULL DEFAULT 0 CHECK (add_series_search_for_cutoff_unmet IN (0, 1)),
  add_series_default_monitored INTEGER NOT NULL DEFAULT 1 CHECK (add_series_default_monitored IN (0, 1)),
  add_series_default_use_season_folders INTEGER NOT NULL DEFAULT 1 CHECK (add_series_default_use_season_folders IN (0, 1)),
  add_series_default_series_type TEXT NOT NULL DEFAULT 'standard',
  add_series_default_monitor_type TEXT NOT NULL DEFAULT 'all',
  add_series_default_language_profile INTEGER,
  add_series_default_quality_profile INTEGER,
  add_series_default_root_folder INTEGER,
  add_series_default_tags_json TEXT NOT NULL DEFAULT '[]',
  default_view_series TEXT NOT NULL DEFAULT 'BLOCK_VIEW',
  default_filtering_series TEXT NOT NULL DEFAULT 'all',
  default_filtering_releases TEXT NOT NULL DEFAULT 'all',
  default_sorting_series TEXT NOT NULL DEFAULT 'abc',
  default_sorting_releases TEXT NOT NULL DEFAULT 'weight',
  default_sorting_series_ascending INTEGER NOT NULL DEFAULT 1 CHECK (default_sorting_series_ascending IN (0, 1)),
  default_sorting_releases_ascending INTEGER NOT NULL DEFAULT 1 CHECK (default_sorting_releases_ascending IN (0, 1)),
  remove_series_delete_files INTEGER NOT NULL DEFAULT 0 CHECK (remove_series_delete_files IN (0, 1)),
  remove_series_exclusion_list INTEGER NOT NULL DEFAULT 0 CHECK (remove_series_exclusion_list IN (0, 1)),
  upcoming_future_days INTEGER NOT NULL DEFAULT 7,
  queue_page_size INTEGER NOT NULL DEFAULT 50,
  queue_refresh_rate INTEGER NOT NULL DEFAULT 15,
  queue_remove_download_client INTEGER NOT NULL DEFAULT 0 CHECK (queue_remove_download_client IN (0, 1)),
  queue_add_blocklist INTEGER NOT NULL DEFAULT 0 CHECK (queue_add_blocklist IN (0, 1)),
  content_page_size INTEGER NOT NULL DEFAULT 10,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS lidarr_preferences (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  navigation_index INTEGER NOT NULL DEFAULT 0,
  add_monitored_status TEXT NOT NULL DEFAULT 'all',
  add_artist_search_for_missing INTEGER NOT NULL DEFAULT 1 CHECK (add_artist_search_for_missing IN (0, 1)),
  add_album_folders INTEGER NOT NULL DEFAULT 1 CHECK (add_album_folders IN (0, 1)),
  add_quality_profile_json TEXT NOT NULL DEFAULT 'null',
  add_metadata_profile_json TEXT NOT NULL DEFAULT 'null',
  add_root_folder_json TEXT NOT NULL DEFAULT 'null',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS nzbget_preferences (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  navigation_index INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS sabnzbd_preferences (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  navigation_index INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS tautulli_preferences (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  navigation_index INTEGER NOT NULL DEFAULT 0,
  navigation_index_graphs INTEGER NOT NULL DEFAULT 0,
  navigation_index_libraries_details INTEGER NOT NULL DEFAULT 0,
  navigation_index_media_details INTEGER NOT NULL DEFAULT 0,
  navigation_index_user_details INTEGER NOT NULL DEFAULT 0,
  refresh_rate INTEGER NOT NULL DEFAULT 10,
  content_load_length INTEGER NOT NULL DEFAULT 125,
  statistics_stats_count INTEGER NOT NULL DEFAULT 3,
  termination_message TEXT NOT NULL DEFAULT '',
  graphs_days INTEGER NOT NULL DEFAULT 30,
  graphs_linechart_days INTEGER NOT NULL DEFAULT 14,
  graphs_months INTEGER NOT NULL DEFAULT 6,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS indexers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  display_name TEXT NOT NULL,
  host TEXT NOT NULL,
  api_key TEXT NOT NULL DEFAULT '',
  headers_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS external_modules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  display_name TEXT NOT NULL,
  host TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS dismissed_banners (
  key TEXT PRIMARY KEY,
  dismissed_at TEXT NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp INTEGER NOT NULL,
  type TEXT NOT NULL,
  class_name TEXT NOT NULL DEFAULT '',
  method_name TEXT NOT NULL DEFAULT '',
  message TEXT NOT NULL,
  error TEXT NOT NULL DEFAULT '',
  stack_trace_json TEXT NOT NULL DEFAULT '[]',
  created_at TEXT NOT NULL
) STRICT;
CREATE INDEX IF NOT EXISTS logs_timestamp_idx ON logs(timestamp DESC);
`)
	return err
}

func migrateLegacyServiceConfigs(ctx context.Context, tx *sql.Tx) error {
	exists, err := tableExists(ctx, tx, "service_configs")
	if err != nil || !exists {
		return err
	}
	rows, err := tx.QueryContext(ctx, `
SELECT service, profile, upstream_url, api_key, username, password, headers_json
FROM service_configs;`)
	if err != nil {
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var cfg serviceConfig
		var headersJSON string
		if err := rows.Scan(&cfg.Service, &cfg.Profile, &cfg.UpstreamURL, &cfg.APIKey, &cfg.Username, &cfg.Password, &headersJSON); err != nil {
			return err
		}
		if cfg.Profile == "" {
			cfg.Profile = defaultProfileID
		}
		now := nowText()
		if _, err := tx.ExecContext(ctx, `
INSERT INTO profiles (id, display_name, sort_order, created_at, updated_at)
VALUES (?, ?, 0, ?, ?)
ON CONFLICT(id) DO NOTHING;`, cfg.Profile, cfg.Profile, now, now); err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `
INSERT INTO service_connections (
  profile_id, service, enabled, upstream_url, api_key, username, password, headers_json, created_at, updated_at
) VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(profile_id, service) DO UPDATE SET
  enabled = excluded.enabled,
  upstream_url = excluded.upstream_url,
  api_key = excluded.api_key,
  username = excluded.username,
  password = excluded.password,
  headers_json = excluded.headers_json,
  updated_at = excluded.updated_at;`,
			cfg.Profile, cfg.Service, cfg.UpstreamURL, cfg.APIKey, cfg.Username, cfg.Password, headersJSON, now, now); err != nil {
			return err
		}
	}
	return rows.Err()
}

func tableExists(ctx context.Context, tx *sql.Tx, name string) (bool, error) {
	var count int
	err := tx.QueryRowContext(ctx, `
SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?;`, name).Scan(&count)
	return count > 0, err
}

func (s *store) bootstrapDefaults(ctx context.Context) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	now := nowText()
	if _, err := tx.ExecContext(ctx, `
INSERT INTO profiles (id, display_name, sort_order, created_at, updated_at)
VALUES (?, ?, 0, ?, ?)
ON CONFLICT(id) DO NOTHING;`, defaultProfileID, defaultProfileID, now, now); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `
INSERT INTO app_preferences (id, active_profile, created_at, updated_at)
VALUES (1, ?, ?, ?)
ON CONFLICT(id) DO NOTHING;`, defaultProfileID, now, now); err != nil {
		return err
	}
	for _, table := range []string{
		"radarr_preferences",
		"sonarr_preferences",
		"lidarr_preferences",
		"nzbget_preferences",
		"sabnzbd_preferences",
		"tautulli_preferences",
	} {
		if _, err := tx.ExecContext(ctx, fmt.Sprintf(`
INSERT INTO %s (id, created_at, updated_at)
VALUES (1, ?, ?)
ON CONFLICT(id) DO NOTHING;`, table), now, now); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (s *store) listServices(ctx context.Context) ([]serviceConfig, error) {
	rows, err := s.db.QueryContext(ctx, `
SELECT service, profile_id, upstream_url, api_key, username, password, headers_json
FROM service_connections
WHERE enabled = 1 AND upstream_url != ''
ORDER BY service, profile_id;`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var configs []serviceConfig
	for rows.Next() {
		var cfg serviceConfig
		var headersJSON string
		if err := rows.Scan(
			&cfg.Service,
			&cfg.Profile,
			&cfg.UpstreamURL,
			&cfg.APIKey,
			&cfg.Username,
			&cfg.Password,
			&headersJSON,
		); err != nil {
			return nil, err
		}
		cfg.Headers = unmarshalHeaders(headersJSON)
		configs = append(configs, cfg)
	}
	return configs, rows.Err()
}

func (s *store) getService(ctx context.Context, service, profile string) (serviceConfig, error) {
	var cfg serviceConfig
	var headersJSON string
	err := s.db.QueryRowContext(ctx, `
SELECT service, profile_id, upstream_url, api_key, username, password, headers_json
FROM service_connections
WHERE service = ? AND profile_id = ? AND enabled = 1 AND upstream_url != '';`, service, profile).Scan(
		&cfg.Service,
		&cfg.Profile,
		&cfg.UpstreamURL,
		&cfg.APIKey,
		&cfg.Username,
		&cfg.Password,
		&headersJSON,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return serviceConfig{}, errNotFound
	}
	if err != nil {
		return serviceConfig{}, err
	}
	cfg.Headers = unmarshalHeaders(headersJSON)
	return cfg, nil
}

func (s *store) putService(ctx context.Context, cfg serviceConfig) error {
	headersJSON, err := marshalHeaders(cfg.Headers)
	if err != nil {
		return err
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	now := nowText()
	if _, err := tx.ExecContext(ctx, `
INSERT INTO profiles (id, display_name, sort_order, created_at, updated_at)
VALUES (?, ?, 0, ?, ?)
ON CONFLICT(id) DO NOTHING;`, cfg.Profile, cfg.Profile, now, now); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `
INSERT INTO service_connections (
  profile_id, service, enabled, upstream_url, api_key, username, password, headers_json, created_at, updated_at
) VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(profile_id, service) DO UPDATE SET
  enabled = 1,
  upstream_url = excluded.upstream_url,
  api_key = excluded.api_key,
  username = excluded.username,
  password = excluded.password,
  headers_json = excluded.headers_json,
  updated_at = excluded.updated_at;`,
		cfg.Profile,
		cfg.Service,
		cfg.UpstreamURL,
		cfg.APIKey,
		cfg.Username,
		cfg.Password,
		headersJSON,
		now,
		now,
	); err != nil {
		return err
	}
	return tx.Commit()
}

func (s *store) deleteService(ctx context.Context, service, profile string) error {
	result, err := s.db.ExecContext(ctx, `
DELETE FROM service_connections
WHERE service = ? AND profile_id = ?;`, service, profile)
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

func nowText() string {
	return time.Now().UTC().Format(time.RFC3339)
}
