part of '../../controllers.dart';

Future<List<SonarrSeries>> _commandGetSeriesLookup(
  Dio client, {
  required String term,
}) async {
  Response response = await client.get(
    'series/lookup',
    queryParameters: {'term': term},
  );
  return (response.data as List)
      .map((series) => SonarrSeries.fromJson(series))
      .toList();
}
