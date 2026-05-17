part of '../../commands.dart';

Future<RadarrExclusion> _commandGetExclusions(
  Dio client, {
  required int exclusionId,
}) async {
  Response response = await client.get('exclusions/$exclusionId');
  return RadarrExclusion.fromJson(response.data);
}
