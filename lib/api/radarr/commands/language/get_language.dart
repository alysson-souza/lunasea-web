part of '../../commands.dart';

Future<RadarrLanguage> _commandGetLanguage(
  Dio client, {
  required int languageId,
}) async {
  Response response = await client.get('language/$languageId');
  return RadarrLanguage.fromJson(response.data);
}
