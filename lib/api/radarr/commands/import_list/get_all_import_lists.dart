part of '../../commands.dart';

Future<List<RadarrImportList>> _commandGetAllImportLists(Dio client) async {
  Response response = await client.get('importlist');
  return (response.data as List)
      .map((list) => RadarrImportList.fromJson(list))
      .toList();
}
