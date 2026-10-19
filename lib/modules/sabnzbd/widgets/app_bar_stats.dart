import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/extensions/string/string.dart';
import 'package:lunasea/modules/sabnzbd.dart';
import 'package:lunasea/modules/sabnzbd/widgets/server_actions.dart';

class SABnzbdAppBarStats extends StatelessWidget {
  final SABnzbdState? state;

  const SABnzbdAppBarStats({super.key, this.state});

  @override
  Widget build(BuildContext context) {
    final state = this.state;
    if (state == null) {
      return Consumer<SABnzbdState>(
        builder: (context, state, _) => _stats(context, state),
      );
    }
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => _stats(context, state),
    );
  }

  Widget _stats(BuildContext context, SABnzbdState state) => GestureDetector(
    onTap: state.error || state.queueStale || state.status == null
        ? null
        : () => SABnzbdServerActions.speedLimit(context, state),
    child: Center(
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: LunaColours.grey,
            fontSize: LunaUI.FONT_SIZE_H3,
          ),
          children: [
            TextSpan(
              text: _status(state.paused, state.currentSpeed),
              style: const TextStyle(
                fontWeight: LunaUI.FONT_WEIGHT_BOLD,
                fontSize: LunaUI.FONT_SIZE_HEADER,
                color: LunaColours.accent,
              ),
            ),
            const TextSpan(text: '\n'),
            TextSpan(
              text: state.queueTimeLeft == '0:00:00'
                  ? '―'
                  : state.queueTimeLeft,
            ),
            TextSpan(text: LunaUI.TEXT_BULLET.pad()),
            TextSpan(
              text: state.queueSizeLeft == '0.0 B' ? '―' : state.queueSizeLeft,
            ),
          ],
        ),
        overflow: TextOverflow.fade,
        maxLines: 2,
        softWrap: false,
        textAlign: TextAlign.right,
      ),
    ),
  );

  String _status(bool paused, String speed) => paused
      ? 'Paused'
      : speed == '0.0 B/s'
      ? 'Idle'
      : speed;
}
