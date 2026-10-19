import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sabnzbd/widgets/server_actions.dart';
import 'package:lunasea/modules/sabnzbd.dart';

class SABnzbdQueueFAB extends StatefulWidget {
  final ScrollController scrollController;
  final SABnzbdState? state;

  const SABnzbdQueueFAB({
    super.key,
    required this.scrollController,
    this.state,
  });

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<SABnzbdQueueFAB> with TickerProviderStateMixin {
  AnimationController? _iconController;
  AnimationController? _hideController;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _setupIconController();
    _setupHideController();
  }

  @override
  void dispose() {
    _iconController?.dispose();
    _hideController?.dispose();
    widget.scrollController.removeListener(scrollControllerListener);
    super.dispose();
  }

  void _setupIconController() {
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: LunaUI.ANIMATION_SPEED),
    );
  }

  void _setupHideController() {
    _hideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: LunaUI.ANIMATION_SPEED),
    );
    _hideController!.forward();
    widget.scrollController.addListener(scrollControllerListener);
  }

  void scrollControllerListener() {
    if (!widget.scrollController.hasClients) return;
    switch (widget.scrollController.position.userScrollDirection) {
      case ScrollDirection.forward:
        if (!_visible) {
          _hideController!.forward();
          _visible = true;
        }
        break;
      case ScrollDirection.reverse:
        if (_visible) {
          _hideController!.reverse();
          _visible = false;
        }
        break;
      case ScrollDirection.idle:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state == null) {
      return Consumer<SABnzbdState>(
        builder: (context, state, _) => _button(context, state),
      );
    }
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => _button(context, state),
    );
  }

  Widget _button(BuildContext context, SABnzbdState state) {
    state.paused ? _iconController!.forward() : _iconController!.reverse();
    if (state.error || state.queueStale || state.status == null) {
      return const SizedBox.shrink();
    }
    return ScaleTransition(
      scale: _hideController!,
      child: InkWell(
        child: LunaFloatingActionButtonAnimated(
          onPressed: () => SABnzbdServerActions.toggle(context, state),
          icon: AnimatedIcons.pause_play,
          controller: _iconController,
        ),
        onLongPress: () => SABnzbdServerActions.pauseFor(context, state),
        borderRadius: BorderRadius.circular(28.0),
      ),
    );
  }
}
