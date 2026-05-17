part of '../../controllers.dart';

Future<List<SonarrExclusion>> _commandGetExclusionList(Dio client) async {
  Response response = await client.get('importlistexclusion');
  return (response.data as List)
      .map((series) => SonarrExclusion.fromJson(series))
      .toList();
}
