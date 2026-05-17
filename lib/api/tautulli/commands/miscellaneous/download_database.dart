part of '../../commands.dart';

Future<Uint8List?> _commandDownloadDatabase(Dio client) async {
  Response response = await client.get(
    '/',
    queryParameters: {'cmd': 'download_database'},
    options: Options(responseType: ResponseType.bytes),
  );
  return (response.data as Uint8List?);
}
