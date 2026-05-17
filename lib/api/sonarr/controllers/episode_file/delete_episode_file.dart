part of '../../controllers.dart';

Future<void> _commandDeleteEpisodeFile(
  Dio client, {
  required int episodeFileId,
}) async {
  await client.delete('episodefile/$episodeFileId');
}
