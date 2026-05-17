part of '../../commands.dart';

Future<RadarrCommand> _commandRSSSync(Dio client) async {
  Response response = await client.post('command', data: {'name': 'RssSync'});
  return RadarrCommand.fromJson(response.data);
}
