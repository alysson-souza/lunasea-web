part of '../../commands.dart';

Future<void> _commandDeleteMovieFile(
  Dio client, {
  required int movieFileId,
}) async {
  await client.delete('moviefile/$movieFileId');
  return;
}
