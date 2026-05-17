part of '../../commands.dart';

Future<void> _commandDeleteTag(Dio client, {required int id}) async {
  await client.delete('tag/$id');
  return;
}
