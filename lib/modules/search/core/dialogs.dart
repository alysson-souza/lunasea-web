import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/search/core/download_target.dart';
import 'package:lunasea/utils/profile_tools.dart';

class SearchDialogs {
  Future<Tuple2<bool, SearchDownloadTarget?>> downloadResult(
    BuildContext context,
  ) async {
    bool _flag = false;
    SearchDownloadTarget? _target;

    void _setValues(bool flag, SearchDownloadTarget target) {
      _flag = flag;
      _target = target;
      Navigator.of(context).pop();
    }

    await LunaDialog.dialog(
      context: context,
      title: 'search.Download'.tr(),
      customContent: Consumer<ProfilesStore>(
        builder: (context, store, _) => LunaDialog.content(
          children: [
            Padding(
              child: LunaPopupMenuButton<String>(
                tooltip: 'lunasea.ChangeProfiles'.tr(),
                child: Container(
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: Text(
                          store.activeProfile,
                          style: const TextStyle(fontSize: LunaUI.FONT_SIZE_H3),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: LunaColours.accent,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.only(bottom: 2.0),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: LunaColours.accent, width: 2.0),
                    ),
                  ),
                ),
                onSelected: (result) async {
                  HapticFeedback.selectionClick();
                  await LunaProfileTools(
                    context.read<ProfilesStore>(),
                  ).changeTo(result);
                },
                itemBuilder: (context) {
                  return <PopupMenuEntry<String>>[
                    for (final profile in store.profiles)
                      PopupMenuItem<String>(
                        value: profile,
                        child: Text(
                          profile,
                          style: TextStyle(
                            fontSize: LunaUI.FONT_SIZE_H3,
                            color: store.activeProfile == profile
                                ? LunaColours.accent
                                : Colors.white,
                          ),
                        ),
                      ),
                  ];
                },
              ),
              padding: LunaDialog.tileContentPadding().add(
                const EdgeInsets.only(bottom: 16.0),
              ),
            ),
            for (final entry in SearchDownloadTarget.available(
              store.active,
            ).asMap().entries)
              LunaDialog.tile(
                icon: entry.value.icon,
                iconColor: LunaColours().byListIndex(entry.key),
                text: entry.value.label,
                onTap: () => _setValues(true, entry.value),
              ),
          ],
        ),
      ),
      contentPadding: LunaDialog.listDialogContentPadding(),
    );
    return Tuple2(_flag, _target);
  }
}
