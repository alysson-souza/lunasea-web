part of '../../controllers.dart';

Future<List<SonarrLanguageProfile>> _commandGetLanguageProfiles(
  Dio client,
) async {
  Response response = await client.get('languageprofile');
  return (response.data as List)
      .map((profile) => SonarrLanguageProfile.fromJson(profile))
      .toList();
}
