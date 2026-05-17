import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/extensions/int/bytes.dart';
import 'package:lunasea/extensions/string/string.dart';
import 'package:lunasea/modules/search/core/download_target.dart';
import 'package:lunasea/modules/search.dart';

class SearchResultTile extends StatelessWidget {
  final NewznabResultData data;

  const SearchResultTile({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return LunaExpandableListTile(
      title: data.title,
      collapsedSubtitles: [_subtitle1(), _subtitle2()],
      expandedTableContent: _tableContent(),
      collapsedTrailing: _trailing(context),
      expandedTableButtons: _tableButtons(context),
    );
  }

  TextSpan _subtitle1() {
    return TextSpan(
      children: [
        TextSpan(text: data.size.asBytes()),
        TextSpan(text: LunaUI.TEXT_BULLET.pad()),
        TextSpan(text: data.category),
      ],
    );
  }

  TextSpan _subtitle2() {
    return TextSpan(text: data.age);
  }

  List<BackendPreferenceGroupContent> _tableContent() {
    return [
      BackendPreferenceGroupContent(title: 'search.Age'.tr(), body: data.age),
      BackendPreferenceGroupContent(
        title: 'search.Size'.tr(),
        body: data.size.asBytes(),
      ),
      BackendPreferenceGroupContent(
        title: 'search.Category'.tr(),
        body: data.category,
      ),
      if (SearchPreferences.SHOW_LINKS.read())
        BackendPreferenceGroupContent(title: '', body: ''),
      if (SearchPreferences.SHOW_LINKS.read())
        BackendPreferenceGroupContent(
          title: 'search.Comments'.tr(),
          body: data.linkComments,
          bodyIsUrl: true,
        ),
      if (SearchPreferences.SHOW_LINKS.read())
        BackendPreferenceGroupContent(
          title: 'search.Download'.tr(),
          body: data.linkDownload,
          bodyIsUrl: true,
        ),
    ];
  }

  List<LunaButton> _tableButtons(BuildContext context) {
    return [
      LunaButton.text(
        icon: Icons.download_rounded,
        text: 'search.Download'.tr(),
        onTap: () async => _sendToClient(context),
      ),
    ];
  }

  LunaIconButton _trailing(BuildContext context) {
    return LunaIconButton(
      icon: Icons.download_rounded,
      onPressed: () => _sendToClient(context),
    );
  }

  Future<void> _sendToClient(BuildContext context) async {
    Tuple2<bool, SearchDownloadTarget?> result = await SearchDialogs()
        .downloadResult(context);
    if (result.item1) result.item2!.execute(context, data);
  }
}
