import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/radarr.dart';

class RadarrMovieDetailsFilesExtraFileBlock extends StatelessWidget {
  final RadarrExtraFile file;

  const RadarrMovieDetailsFilesExtraFileBlock({
    Key? key,
    required this.file,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BackendPreferenceGroupCard(
      content: [
        BackendPreferenceGroupContent(
            title: 'relative path', body: file.lunaRelativePath),
        BackendPreferenceGroupContent(title: 'type', body: file.lunaType),
        BackendPreferenceGroupContent(
            title: 'extension', body: file.lunaExtension),
      ],
    );
  }
}
