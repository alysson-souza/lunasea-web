import 'package:flutter/material.dart';
import 'package:lunasea/vendor.dart';

enum CalendarStartingType {
  CALENDAR,
  SCHEDULE,
}

extension CalendarStartingTypeExtension on CalendarStartingType {
  String get name {
    switch (this) {
      case CalendarStartingType.SCHEDULE:
        return 'dashboard.Schedule'.tr();
      case CalendarStartingType.CALENDAR:
        return 'dashboard.Calendar'.tr();
    }
  }

  String get key {
    switch (this) {
      case CalendarStartingType.SCHEDULE:
        return 'schedule';
      case CalendarStartingType.CALENDAR:
        return 'calendar';
    }
  }

  IconData get icon {
    switch (this) {
      case CalendarStartingType.SCHEDULE:
        return Icons.calendar_today_rounded;
      case CalendarStartingType.CALENDAR:
        return Icons.calendar_view_day_rounded;
    }
  }

  CalendarStartingType? fromKey(String? key) {
    switch (key) {
      case 'schedule':
        return CalendarStartingType.SCHEDULE;
      case 'calendar':
        return CalendarStartingType.CALENDAR;
      default:
        return null;
    }
  }
}
