import 'package:lunasea/core.dart';
import 'package:lunasea/types/log_type.dart';
import 'package:stack_trace/stack_trace.dart';

class LunaLog {
  final int timestamp;
  final LunaLogType type;
  final String? className;
  final String? methodName;
  final String message;
  final String? error;
  final String? stackTrace;

  LunaLog({
    required this.timestamp,
    required this.type,
    this.className,
    this.methodName,
    required this.message,
    this.error,
    this.stackTrace,
  });

  factory LunaLog.withMessage({
    required LunaLogType type,
    required String message,
    String? className,
    String? methodName,
  }) {
    int timestamp = DateTime.now().millisecondsSinceEpoch;
    return LunaLog(
      timestamp: timestamp,
      type: type,
      message: message,
    );
  }

  factory LunaLog.withError({
    required LunaLogType type,
    required String message,
    required dynamic error,
    required StackTrace? stackTrace,
    String? className,
    String? methodName,
  }) {
    int timestamp = DateTime.now().millisecondsSinceEpoch;
    Trace? trace = stackTrace == null ? null : Trace.from(stackTrace);
    String? _className, _methodName;
    if ((trace?.frames.length ?? 0) >= 1) {
      _className = trace?.frames[0].uri.toString();
      _methodName = trace?.frames[0].member.toString();
    }
    return LunaLog(
      timestamp: timestamp,
      type: type,
      className: className ?? _className,
      methodName: methodName ?? _methodName,
      message: message,
      error: error?.toString(),
      stackTrace: trace?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "timestamp":
          DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String(),
      "type": type.title,
      "message": message,
      if (className?.isNotEmpty ?? false) "class_name": className,
      if (methodName?.isNotEmpty ?? false) "method_name": methodName,
      if (error?.isNotEmpty ?? false) "error": error,
      if (stackTrace?.isNotEmpty ?? false)
        "stack_trace": stackTrace?.trim().split('\n') ?? [],
    };
  }
}
