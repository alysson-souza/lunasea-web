part of '../../controllers.dart';

Future<void> _commandDeleteEpisodeFiles(
  Dio client, {
  required List<int> episodeFileIds,
}) async {
  await client.delete(
    'episodefile/bulk',
    data: {'episodeFileIds': episodeFileIds},
  );
}
