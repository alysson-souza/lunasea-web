import 'dart:async';
import 'dart:collection';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class SABnzbdPollingScope extends StatefulWidget {
  final List<SABnzbdState> states;
  final String routePath;
  final Widget child;

  const SABnzbdPollingScope({
    super.key,
    required this.states,
    required this.routePath,
    required this.child,
  });

  @override
  State<SABnzbdPollingScope> createState() => _SABnzbdPollingScopeState();
}

class _SABnzbdPollingScopeState extends State<SABnzbdPollingScope>
    with WidgetsBindingObserver {
  final Set<SABnzbdState> _acquired = HashSet.identity();
  RouteInformationProvider? _routeInformation;
  ModalRoute<dynamic>? _route;
  late AppLifecycleState _lifecycle;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    _lifecycle = binding.lifecycleState ?? AppLifecycleState.resumed;
    binding.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final information = GoRouter.maybeOf(context)?.routeInformationProvider;
    if (!identical(information, _routeInformation)) {
      _routeInformation?.removeListener(_scheduleReconciliation);
      _routeInformation = information;
      information?.addListener(_scheduleReconciliation);
    }
    _route = ModalRoute.of(context);
    _scheduleReconciliation();
  }

  @override
  void didUpdateWidget(covariant SABnzbdPollingScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleReconciliation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _scheduleReconciliation();
  }

  void _scheduleReconciliation() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    scheduleMicrotask(_reconcileWhenIdle);
  }

  void _reconcileWhenIdle() {
    if (!mounted) return;
    // Router listeners can run in a build or a frame's microtask phase.
    // Leave the entire frame before publishing demand to source listeners.
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scheduleMicrotask(_reconcileWhenIdle);
      });
      SchedulerBinding.instance.ensureVisualUpdate();
      return;
    }
    _scheduled = false;
    final route = _route;
    final visible =
        route?.isCurrent == true &&
        (route is PopupRoute ||
            route is ModalSheetRoute ||
            _routeInformation == null ||
            _routeInformation!.value.uri.path == widget.routePath);
    final desired = HashSet<SABnzbdState>.identity();
    if (visible && _lifecycle == AppLifecycleState.resumed) {
      desired.addAll(widget.states.where((state) => !state.isDisposed));
    }

    final removed = _acquired
        .where((state) => !desired.contains(state))
        .toList();
    for (final state in removed) {
      _acquired.remove(state);
      if (!state.isDisposed) state.releaseQueue();
    }
    for (final state in desired) {
      if (_acquired.add(state)) state.acquireQueue();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeInformation?.removeListener(_scheduleReconciliation);
    final released = _acquired.toList();
    _acquired.clear();
    scheduleMicrotask(() {
      for (final state in released) {
        if (!state.isDisposed) state.releaseQueue();
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
