import 'package:lunasea/vendor.dart';

enum CalendarStartingDay {
  MONDAY,
  TUESDAY,
  WEDNESDAY,
  THURSDAY,
  FRIDAY,
  SATURDAY,
  SUNDAY,
}

extension CalendarStartingDayExtension on CalendarStartingDay {
  StartingDayOfWeek get data {
    switch (this) {
      case CalendarStartingDay.MONDAY:
        return StartingDayOfWeek.monday;
      case CalendarStartingDay.TUESDAY:
        return StartingDayOfWeek.tuesday;
      case CalendarStartingDay.WEDNESDAY:
        return StartingDayOfWeek.wednesday;
      case CalendarStartingDay.THURSDAY:
        return StartingDayOfWeek.thursday;
      case CalendarStartingDay.FRIDAY:
        return StartingDayOfWeek.friday;
      case CalendarStartingDay.SATURDAY:
        return StartingDayOfWeek.saturday;
      case CalendarStartingDay.SUNDAY:
        return StartingDayOfWeek.sunday;
    }
  }

  String get name {
    switch (this) {
      case CalendarStartingDay.MONDAY:
        return 'dashboard.Monday'.tr();
      case CalendarStartingDay.TUESDAY:
        return 'dashboard.Tuesday'.tr();
      case CalendarStartingDay.WEDNESDAY:
        return 'dashboard.Wednesday'.tr();
      case CalendarStartingDay.THURSDAY:
        return 'dashboard.Thursday'.tr();
      case CalendarStartingDay.FRIDAY:
        return 'dashboard.Friday'.tr();
      case CalendarStartingDay.SATURDAY:
        return 'dashboard.Saturday'.tr();
      case CalendarStartingDay.SUNDAY:
        return 'dashboard.Sunday'.tr();
    }
  }

  String get key {
    switch (this) {
      case CalendarStartingDay.MONDAY:
        return 'mon';
      case CalendarStartingDay.TUESDAY:
        return 'tue';
      case CalendarStartingDay.WEDNESDAY:
        return 'wed';
      case CalendarStartingDay.THURSDAY:
        return 'thu';
      case CalendarStartingDay.FRIDAY:
        return 'fri';
      case CalendarStartingDay.SATURDAY:
        return 'sat';
      case CalendarStartingDay.SUNDAY:
        return 'sun';
    }
  }

  CalendarStartingDay? fromKey(String key) {
    switch (key) {
      case 'mon':
        return CalendarStartingDay.MONDAY;
      case 'tue':
        return CalendarStartingDay.TUESDAY;
      case 'wed':
        return CalendarStartingDay.WEDNESDAY;
      case 'thu':
        return CalendarStartingDay.THURSDAY;
      case 'fri':
        return CalendarStartingDay.FRIDAY;
      case 'sat':
        return CalendarStartingDay.SATURDAY;
      case 'sun':
        return CalendarStartingDay.SUNDAY;
      default:
        return null;
    }
  }
}
