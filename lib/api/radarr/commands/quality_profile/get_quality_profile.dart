part of '../../commands.dart';

Future<RadarrQualityProfile> _commandGetQualityProfile(
  Dio client, {
  required int profileId,
}) async {
  Response response = await client.get('qualityprofile/$profileId');
  return RadarrQualityProfile.fromJson(response.data);
}
