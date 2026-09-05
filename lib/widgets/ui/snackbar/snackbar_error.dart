import 'package:lunasea/core.dart';

Future<void> showLunaErrorSnackBar({
  required String title,
  dynamic error,
  String? message,
  bool showButton = false,
  String buttonText = 'view',
  Function? buttonOnPressed,
}) async => showLunaSnackBar(
  title: title,
  message:
      message ??
      (error is DioException ? _dioSummary(error) : null) ??
      LunaLogger.checkLogsMessage,
  type: LunaSnackbarType.ERROR,
  showButton: error != null || showButton,
  buttonText: buttonText,
  buttonOnPressed: () async {
    if (error != null) {
      LunaDialogs().textPreview(LunaState.context, 'Error', error.toString());
    } else if (buttonOnPressed != null) {
      buttonOnPressed();
    }
  },
);

/// Short request context for the snackbar body, derived from the message the
/// error-context interceptor attached to the exception (method + URL + status).
String? _dioSummary(DioException error) {
  final message = error.message;
  if (message == null || message.isEmpty) return null;
  final lines = message.split('\n');
  final statusLine = lines.firstWhere(
    (line) => line.startsWith('Status:'),
    orElse: () => '',
  );
  return statusLine.isEmpty ? lines.first : '${lines.first} · $statusLine';
}
