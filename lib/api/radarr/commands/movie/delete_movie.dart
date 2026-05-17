part of '../../commands.dart';

Future<void> _commandDeleteMovie(
  Dio client, {
  required int movieId,
  bool addImportExclusion = false,
  bool deleteFiles = false,
}) async {
  await client.delete(
    'movie/$movieId',
    queryParameters: {
      'addImportExclusion': addImportExclusion,
      'deleteFiles': deleteFiles,
    },
  );
  return;
}
