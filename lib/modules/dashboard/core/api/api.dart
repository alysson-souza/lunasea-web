import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/system/preferences/dashboard.dart';
import 'package:lunasea/extensions/datetime.dart';
import 'package:lunasea/modules/dashboard/core/api/data/abstract.dart';
import 'package:lunasea/modules/dashboard/core/api/data/lidarr.dart';
import 'package:lunasea/modules/dashboard/core/api/data/radarr.dart';
import 'package:lunasea/modules/dashboard/core/api/data/sonarr.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/system/gateway/service_endpoint.dart';
import 'package:lunasea/system/state.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:lunasea/widgets/ui.dart';
import 'package:lunasea/vendor.dart';

typedef CalendarFetcher =
    Future<List<dynamic>> Function(
      LunaServiceInstance instance,
      DateTime today,
    );

class API {
  final LunaProfile profile;
  final CalendarFetcher? lidarrCalendarFetcher;
  final CalendarFetcher? radarrCalendarFetcher;
  final CalendarFetcher? sonarrCalendarFetcher;

  API._internal({
    required this.profile,
    this.lidarrCalendarFetcher,
    this.radarrCalendarFetcher,
    this.sonarrCalendarFetcher,
  });

  factory API() {
    return API._internal(
      profile: LunaState.context.read<ProfilesStore>().active,
    );
  }

  @visibleForTesting
  factory API.test({
    required LunaProfile profile,
    CalendarFetcher? lidarrCalendarFetcher,
    CalendarFetcher? radarrCalendarFetcher,
    CalendarFetcher? sonarrCalendarFetcher,
  }) {
    return API._internal(
      profile: profile,
      lidarrCalendarFetcher: lidarrCalendarFetcher,
      radarrCalendarFetcher: radarrCalendarFetcher,
      sonarrCalendarFetcher: sonarrCalendarFetcher,
    );
  }

  Future<Map<DateTime, List<CalendarData>>> getUpcoming(DateTime today) async {
    Map<DateTime, List<CalendarData>> _upcoming = {};
    if (DashboardPreferences.CALENDAR_ENABLE_LIDARR.read()) {
      for (final instance in profile.enabledInstances(LunaModule.LIDARR)) {
        await _getLidarrUpcoming(_upcoming, today, instance);
      }
    }
    if (DashboardPreferences.CALENDAR_ENABLE_RADARR.read()) {
      for (final instance in profile.enabledInstances(LunaModule.RADARR)) {
        await _getRadarrUpcoming(_upcoming, today, instance);
      }
    }
    if (DashboardPreferences.CALENDAR_ENABLE_SONARR.read()) {
      for (final instance in profile.enabledInstances(LunaModule.SONARR)) {
        await _getSonarrUpcoming(_upcoming, today, instance);
      }
    }
    return _upcoming;
  }

  Future<void> _getLidarrUpcoming(
    Map<DateTime, List<CalendarData>> map,
    DateTime today,
    LunaServiceInstance instance,
  ) async {
    final data = await _lidarrCalendar(instance, today);
    if (data.isNotEmpty) {
      for (var entry in data) {
        DateTime? date = DateTime.tryParse(
          entry['releaseDate'] ?? '',
        )?.toLocal().floor();
        if (date != null && _isDateWithinBounds(date, today)) {
          List<CalendarData> day = map[date] ?? [];
          day.add(
            CalendarLidarrData(
              id: entry['id'] ?? 0,
              title: entry['artist']['artistName'] ?? 'Unknown Artist',
              sourceInstance: instance.displayName,
              sourceRef: instance.ref,
              albumTitle: entry['title'] ?? 'Unknown Album Title',
              artistId: entry['artist']['id'] ?? 0,
              totalTrackCount: entry['statistics'] != null
                  ? entry['statistics']['totalTrackCount'] ?? 0
                  : 0,
              hasAllFiles:
                  (entry['statistics'] != null
                      ? entry['statistics']['percentOfTracks'] ?? 0
                      : 0) ==
                  100,
            ),
          );
          map[date] = day;
        }
      }
    }
  }

  Future<void> _getRadarrUpcoming(
    Map<DateTime, List<CalendarData>> map,
    DateTime today,
    LunaServiceInstance instance,
  ) async {
    final data = await _radarrCalendar(instance, today);
    if (data.isNotEmpty) {
      for (var entry in data) {
        DateTime? physicalRelease = DateTime.tryParse(
          entry['physicalRelease'] ?? '',
        )?.toLocal().floor();
        DateTime? digitalRelease = DateTime.tryParse(
          entry['digitalRelease'] ?? '',
        )?.toLocal().floor();
        DateTime? release;
        if (physicalRelease != null || digitalRelease != null) {
          if (physicalRelease == null) release = digitalRelease;
          if (digitalRelease == null) release = physicalRelease;
          release ??= digitalRelease!.isBefore(physicalRelease!)
              ? digitalRelease
              : physicalRelease;
          if (_isDateWithinBounds(release, today)) {
            List<CalendarData> day = map[release] ?? [];
            day.add(
              CalendarRadarrData(
                id: entry['id'] ?? 0,
                title: entry['title'] ?? 'Unknown Title',
                sourceInstance: instance.displayName,
                sourceRef: instance.ref,
                hasFile: entry['hasFile'] ?? false,
                fileQualityProfile: entry['hasFile']
                    ? entry['movieFile']['quality']['quality']['name']
                    : '',
                year: entry['year'] ?? 0,
                runtime: entry['runtime'] ?? 0,
                studio: entry['studio'] ?? LunaUI.TEXT_EMDASH,
                releaseDate: release,
              ),
            );
            map[release] = day;
          }
        }
      }
    }
  }

  Future<void> _getSonarrUpcoming(
    Map<DateTime, List<CalendarData>> map,
    DateTime today,
    LunaServiceInstance instance,
  ) async {
    final data = await _sonarrCalendar(instance, today);
    if (data.isNotEmpty) {
      for (var entry in data) {
        DateTime? date = DateTime.tryParse(
          entry['airDateUtc'] ?? '',
        )?.toLocal().floor();
        if (date != null && _isDateWithinBounds(date, today)) {
          List<CalendarData> day = map[date] ?? [];
          day.add(
            CalendarSonarrData(
              id: entry['id'] ?? 0,
              seriesID: entry['seriesId'] ?? 0,
              title: entry['series']['title'] ?? 'Unknown Series',
              sourceInstance: instance.displayName,
              sourceRef: instance.ref,
              episodeTitle: entry['title'] ?? 'Unknown Episode Title',
              seasonNumber: entry['seasonNumber'] ?? -1,
              episodeNumber: entry['episodeNumber'] ?? -1,
              airTime: entry['airDateUtc'] ?? '',
              hasFile: entry['hasFile'] ?? false,
              fileQualityProfile: entry['hasFile']
                  ? entry['episodeFile']['quality']['quality']['name']
                  : '',
            ),
          );
          map[date] = day;
        }
      }
    }
  }

  Future<List<dynamic>> _lidarrCalendar(
    LunaServiceInstance instance,
    DateTime today,
  ) async {
    final fetcher = lidarrCalendarFetcher;
    if (fetcher != null) return fetcher(instance, today);

    final endpoint = LunaServiceEndpoint.fromInstance(instance);
    Dio _client = Dio(
      BaseOptions(
        baseUrl: endpoint.apiBase('api/v1/'),
        queryParameters: {
          if (!endpoint.isGateway && instance.apiKey != '')
            'apikey': instance.apiKey,
          'start': _startDate(today),
          'end': _endDate(today),
        },
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        headers: instance.headers,
        followRedirects: true,
        maxRedirects: 5,
      ),
    );
    Response response = await _client.get('calendar');
    return List<dynamic>.from(response.data);
  }

  Future<List<dynamic>> _radarrCalendar(
    LunaServiceInstance instance,
    DateTime today,
  ) async {
    final fetcher = radarrCalendarFetcher;
    if (fetcher != null) return fetcher(instance, today);

    final endpoint = LunaServiceEndpoint.fromInstance(instance);
    Dio _client = Dio(
      BaseOptions(
        baseUrl: endpoint.apiBase('api/v3/'),
        queryParameters: {
          if (!endpoint.isGateway && instance.apiKey != '')
            'apikey': instance.apiKey,
          'start': _startDate(today),
          'end': _endDate(today),
        },
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        headers: instance.headers,
        followRedirects: true,
        maxRedirects: 5,
      ),
    );
    Response response = await _client.get('calendar');
    return List<dynamic>.from(response.data);
  }

  Future<List<dynamic>> _sonarrCalendar(
    LunaServiceInstance instance,
    DateTime today,
  ) async {
    final fetcher = sonarrCalendarFetcher;
    if (fetcher != null) return fetcher(instance, today);

    final endpoint = LunaServiceEndpoint.fromInstance(instance);
    Dio _client = Dio(
      BaseOptions(
        baseUrl: endpoint.apiBase('api/v3/'),
        queryParameters: {
          if (!endpoint.isGateway && instance.apiKey != '')
            'apikey': instance.apiKey,
          'start': _startDate(today),
          'end': _endDate(today),
        },
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        headers: instance.headers,
        followRedirects: true,
        maxRedirects: 5,
      ),
    );
    Response response = await _client.get(
      'calendar',
      queryParameters: {'includeSeries': true, 'includeEpisodeFile': true},
    );
    return List<dynamic>.from(response.data);
  }

  String _startDate(DateTime today) {
    return DateFormat('y-MM-dd').format(_startBoundDate(today));
  }

  String _endDate(DateTime today) {
    return DateFormat('y-MM-dd').format(_endBoundDate(today));
  }

  DateTime _startBoundDate(DateTime today) {
    return today.subtract(
      Duration(days: DashboardPreferences.CALENDAR_DAYS_PAST.read() + 1),
    );
  }

  DateTime _endBoundDate(DateTime today) {
    return today.add(
      Duration(days: DashboardPreferences.CALENDAR_DAYS_FUTURE.read() + 1),
    );
  }

  bool _isDateWithinBounds(DateTime date, DateTime today) {
    return date.isBetween(_startBoundDate(today), _endBoundDate(today));
  }
}
