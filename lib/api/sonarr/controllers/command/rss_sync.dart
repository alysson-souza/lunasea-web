part of '../../controllers.dart';

Future<SonarrCommand> _commandRSSSync(Dio client) async {
  Response response = await client.post('command', data: {'name': 'RssSync'});
  return SonarrCommand.fromJson(response.data);
}
