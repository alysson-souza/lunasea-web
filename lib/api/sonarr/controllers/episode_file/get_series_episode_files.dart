part of '../../controllers.dart';

Future<List<SonarrEpisodeFile>> _commandGetSeriesEpisodeFiles(
  Dio client, {
  required int seriesId,
}) async {
  Response response = await client.get(
    'episodefile',
    queryParameters: {'seriesId': seriesId},
  );
  return (response.data as List)
      .map((episode) => SonarrEpisodeFile.fromJson(episode))
      .toList();
}
