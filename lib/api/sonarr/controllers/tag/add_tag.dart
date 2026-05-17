part of '../../controllers.dart';

Future<SonarrTag> _commandAddTag(Dio client, {required String label}) async {
  Response response = await client.post('tag', data: {'label': label});
  return SonarrTag.fromJson(response.data);
}
