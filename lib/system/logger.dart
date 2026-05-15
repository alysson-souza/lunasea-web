import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:lunasea/core.dart';
import 'package:lunasea/database/models/log.dart';
import 'package:lunasea/types/exception.dart';
import 'package:lunasea/types/log_type.dart';

class LunaLogger {
  static String get checkLogsMessage => 'lunasea.CheckLogsMessage'.tr();

  void initialize() {
    FlutterError.onError = (details) async {
      if (kDebugMode) FlutterError.dumpErrorToConsole(details);
      Zone.current.handleUncaughtError(
        details.exception,
        details.stack ?? StackTrace.current,
      );
    };
    _compact();
  }

  Future<void> _compact([int count = 50]) async {
    if (LogsStore.currentLogs.length <= count) return;
    final entries = LogsStore.currentKeys
        .map((key) => MapEntry(key, LogsStore.readLog(key)!))
        .toList();
    entries.sort((a, b) => b.value.timestamp.compareTo(a.value.timestamp));
    for (final entry in entries.skip(count)) {
      await LogsStore.deleteLog(entry.key);
    }
  }

  Future<String> export() async {
    final logs = LogsStore.currentLogs.map((log) => log.toJson()).toList();
    final encoder = JsonEncoder.withIndent(' '.repeat(4));
    return encoder.convert(logs);
  }

  Future<void> clear() async => LogsStore.clearLogEntries();

  void debug(String message) {
    LunaLog log = LunaLog.withMessage(
      type: LunaLogType.DEBUG,
      message: message,
    );
    LogsStore.createLog(log);
  }

  void warning(String message, [String? className, String? methodName]) {
    LunaLog log = LunaLog.withMessage(
      type: LunaLogType.WARNING,
      message: message,
      className: className,
      methodName: methodName,
    );
    LogsStore.createLog(log);
  }

  void error(String message, dynamic error, StackTrace? stackTrace) {
    if (kDebugMode) {
      print(message);
      print(error);
      print(stackTrace);
    }

    if (error is! NetworkImageLoadException) {
      LunaLog log = LunaLog.withError(
        type: LunaLogType.ERROR,
        message: message,
        error: error,
        stackTrace: stackTrace,
      );
      LogsStore.createLog(log);
    }
  }

  void critical(dynamic error, StackTrace stackTrace) {
    if (kDebugMode) {
      print(error);
      print(stackTrace);
    }

    if (error is! NetworkImageLoadException) {
      LunaLog log = LunaLog.withError(
        type: LunaLogType.CRITICAL,
        message: error?.toString() ?? LunaUI.TEXT_EMDASH,
        error: error,
        stackTrace: stackTrace,
      );
      LogsStore.createLog(log);
    }
  }

  void exception(LunaException exception, [StackTrace? trace]) {
    switch (exception.type) {
      case LunaLogType.WARNING:
        warning(exception.toString(), exception.runtimeType.toString());
        break;
      case LunaLogType.ERROR:
        error(exception.toString(), exception, trace);
        break;
      default:
        break;
    }
  }
}
