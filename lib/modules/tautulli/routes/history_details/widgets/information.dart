import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/extensions/datetime.dart';
import 'package:lunasea/extensions/duration/timestamp.dart';
import 'package:lunasea/modules/tautulli.dart';

class TautulliHistoryDetailsInformation extends StatelessWidget {
  final TautulliHistoryRecord history;
  final ScrollController scrollController;

  const TautulliHistoryDetailsInformation({
    super.key,
    required this.history,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return LunaListView(
      controller: scrollController,
      children: [
        const LunaHeader(text: 'Metadata'),
        _metadataBlock(),
        const LunaHeader(text: 'Session'),
        _sessionBlock(),
        const LunaHeader(text: 'Player'),
        _playerBlock(),
      ],
    );
  }

  Widget _metadataBlock() {
    return BackendPreferenceGroupCard(
      content: [
        BackendPreferenceGroupContent(title: 'status', body: history.lsStatus),
        BackendPreferenceGroupContent(
          title: 'title',
          body: history.lsFullTitle,
        ),
        if (history.year != null)
          BackendPreferenceGroupContent(
            title: 'year',
            body: history.year.toString(),
          ),
        BackendPreferenceGroupContent(
          title: 'user',
          body: history.friendlyName,
        ),
      ],
    );
  }

  Widget _sessionBlock() {
    return BackendPreferenceGroupCard(
      content: [
        BackendPreferenceGroupContent(title: 'state', body: history.lsState),
        BackendPreferenceGroupContent(
          title: 'date',
          body: DateFormat('yyyy-MM-dd').format(history.date!),
        ),
        BackendPreferenceGroupContent(
          title: 'started',
          body: history.date!.asTimeOnly(),
        ),
        BackendPreferenceGroupContent(
          title: 'stopped',
          body: history.state == null
              ? history.stopped!.asTimeOnly()
              : LunaUI.TEXT_EMDASH,
        ),
        BackendPreferenceGroupContent(
          title: 'paused',
          body: history.pausedCounter!.asWordsTimestamp(),
        ),
      ],
    );
  }

  Widget _playerBlock() {
    return BackendPreferenceGroupCard(
      content: [
        BackendPreferenceGroupContent(
          title: 'location',
          body: history.ipAddress,
        ),
        BackendPreferenceGroupContent(
          title: 'platform',
          body: history.platform,
        ),
        BackendPreferenceGroupContent(title: 'product', body: history.product),
        BackendPreferenceGroupContent(title: 'player', body: history.player),
      ],
    );
  }
}
