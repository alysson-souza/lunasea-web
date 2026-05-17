part of '../../controllers.dart';

Future<SonarrEpisodeFile> _commandGetEpisodeFile(
  Dio client, {
  required int episodeId,
}) async {
  Response response = await client.get('episodefile/$episodeId');
  return SonarrEpisodeFile.fromJson(response.data);
}
