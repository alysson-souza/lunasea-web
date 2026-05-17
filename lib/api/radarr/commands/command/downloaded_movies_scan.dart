part of '../../commands.dart';

Future<RadarrCommand> _commandDownloadedMoviesScan(
  Dio client, {
  required String path,
}) async {
  Response response = await client.post(
    'command',
    data: {'name': 'DownloadedMoviesScan', 'path': path},
  );
  return RadarrCommand.fromJson(response.data);
}
