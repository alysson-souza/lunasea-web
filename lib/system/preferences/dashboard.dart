import 'package:lunasea/system/preferences/preference.dart';
import 'package:lunasea/modules/dashboard/core/adapters/calendar_starting_day.dart';
import 'package:lunasea/modules/dashboard/core/adapters/calendar_starting_size.dart';
import 'package:lunasea/modules/dashboard/core/adapters/calendar_starting_type.dart';
import 'package:lunasea/vendor.dart';

enum DashboardPreferences<T> with BackendPreference<T> {
  NAVIGATION_INDEX<int>(0),
  CALENDAR_STARTING_DAY<CalendarStartingDay>(CalendarStartingDay.MONDAY),
  CALENDAR_STARTING_SIZE<CalendarStartingSize>(CalendarStartingSize.ONE_WEEK),
  CALENDAR_STARTING_TYPE<CalendarStartingType>(CalendarStartingType.CALENDAR),
  CALENDAR_ENABLE_LIDARR<bool>(true),
  CALENDAR_ENABLE_RADARR<bool>(true),
  CALENDAR_ENABLE_SONARR<bool>(true),
  CALENDAR_DAYS_PAST<int>(14),
  CALENDAR_DAYS_FUTURE<int>(14);

  @override
  BackendPreferenceGroup get table => BackendPreferenceGroup.dashboard;

  @override
  final T fallback;

  const DashboardPreferences(this.fallback);
  @override
  dynamic export() {
    DashboardPreferences db = this;
    switch (db) {
      case DashboardPreferences.CALENDAR_STARTING_DAY:
        return DashboardPreferences.CALENDAR_STARTING_DAY.read().key;
      case DashboardPreferences.CALENDAR_STARTING_SIZE:
        return DashboardPreferences.CALENDAR_STARTING_SIZE.read().key;
      case DashboardPreferences.CALENDAR_STARTING_TYPE:
        return DashboardPreferences.CALENDAR_STARTING_TYPE.read().key;
      default:
        return super.export();
    }
  }

  @override
  void import(dynamic value) {
    DashboardPreferences db = this;
    dynamic result;

    switch (db) {
      case DashboardPreferences.CALENDAR_STARTING_DAY:
        result = CalendarStartingDay.MONDAY.fromKey(value.toString());
        break;
      case DashboardPreferences.CALENDAR_STARTING_SIZE:
        result = CalendarStartingSize.ONE_WEEK.fromKey(value.toString());
        break;
      case DashboardPreferences.CALENDAR_STARTING_TYPE:
        result = CalendarStartingType.CALENDAR.fromKey(value.toString());
        break;
      default:
        result = value;
        break;
    }

    return super.import(result);
  }
}
