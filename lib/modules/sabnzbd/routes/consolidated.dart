import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sabnzbd/core/consolidated_state.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';
import 'package:lunasea/modules/sabnzbd/routes/consolidated_history.dart';
import 'package:lunasea/modules/sabnzbd/routes/consolidated_queue.dart';
import 'package:lunasea/modules/sabnzbd/widgets/navigation_bar.dart';
import 'package:lunasea/modules/sabnzbd/widgets/polling_scope.dart';
import 'package:lunasea/modules/sabnzbd/widgets/server_actions.dart';
import 'package:lunasea/router/routes/sabnzbd.dart';
import 'package:lunasea/system/consolidated/instance_picker_sheet.dart';
import 'package:lunasea/system/preferences/sabnzbd.dart';

class SABnzbdConsolidatedRoute extends StatelessWidget {
  final int? initialPage;

  const SABnzbdConsolidatedRoute({super.key, this.initialPage});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfilesStore>().active;
    final registry = context.watch<LunaModuleStateRegistry<SABnzbdState>>();
    final instances = profile.enabledInstances(LunaModule.SABNZBD);
    final states = instances.map(registry.get).toList(growable: false);
    return ChangeNotifierProvider<SABnzbdConsolidatedState>(
      key: _SourceKey(profile.key, states),
      create: (_) => SABnzbdConsolidatedState(
        instances: instances,
        instanceStates: states,
      ),
      child: _ConsolidatedShell(initialPage: initialPage),
    );
  }
}

// Registry identities change with configuration; ordered identities also cover
// source membership and order, including an empty active profile.
class _SourceKey extends LocalKey {
  final String profile;
  final List<SABnzbdState> states;

  const _SourceKey(this.profile, this.states);

  @override
  bool operator ==(Object other) =>
      other is _SourceKey &&
      profile == other.profile &&
      listEquals(states, other.states);

  @override
  int get hashCode => Object.hash(profile, Object.hashAll(states));
}

class _ConsolidatedShell extends StatefulWidget {
  final int? initialPage;

  const _ConsolidatedShell({this.initialPage});

  @override
  State<_ConsolidatedShell> createState() => _ConsolidatedShellState();
}

class _ConsolidatedShellState extends State<_ConsolidatedShell>
    with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _refreshKeys = List.generate(
    2,
    (_) => GlobalKey<RefreshIndicatorState>(),
  );
  final _scrollControllers = List.generate(2, (_) => ScrollController());
  late final LunaPageController _pageController;
  late int _selectedPage;
  GoRouter? _router;
  ModalRoute<dynamic>? _modalRoute;
  late AppLifecycleState _lifecycle;
  bool _routeVisible = true;
  bool _historyEntered = false;
  bool _historyRefreshScheduled = false;
  bool _historyRefreshOnEntry = false;

  int _page(int? value) =>
      (value ?? SABnzbdPreferences.NAVIGATION_INDEX.read()).clamp(0, 1).toInt();

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    _lifecycle = binding.lifecycleState ?? AppLifecycleState.resumed;
    binding.addObserver(this);
    _selectedPage = _page(widget.initialPage);
    _pageController = LunaPageController(initialPage: _selectedPage);
    _pageController.addListener(_onPageChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _modalRoute = ModalRoute.of(context);
    final router = GoRouter.maybeOf(context);
    if (!identical(router, _router)) {
      _router?.routeInformationProvider.removeListener(_onRouteChanged);
      _router = router;
      _router?.routeInformationProvider.addListener(_onRouteChanged);
    }
    _onRouteChanged();
  }

  @override
  void didUpdateWidget(covariant _ConsolidatedShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPage == oldWidget.initialPage) return;
    final page = _page(widget.initialPage);
    _selectedPage = page;
    _reconcileHistoryEntry();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || page != _selectedPage) return;
      if (_pageController.hasClients) _pageController.jumpToPage(page);
    });
  }

  void _onPageChanged() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page?.round() ?? _selectedPage;
    if (page == _selectedPage) return;
    setState(() => _selectedPage = page);
    _reconcileHistoryEntry();
  }

  void _onRouteChanged() {
    _routeVisible =
        _modalRoute?.isCurrent == true &&
        (_router == null ||
            _router!.routeInformationProvider.value.uri.path == '/sabnzbd');
    _reconcileHistoryEntry();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _onRouteChanged();
  }

  void _reconcileHistoryEntry() {
    final entered =
        _routeVisible &&
        _lifecycle == AppLifecycleState.resumed &&
        _selectedPage == 1;
    final newlyEntered = entered && !_historyEntered;
    _historyEntered = entered;
    if (!entered) return;
    final states = context.read<SABnzbdConsolidatedState>().instanceStates;
    if (newlyEntered || states.any(_needsHistory)) {
      _scheduleHistoryRefresh(refreshOnEntry: newlyEntered);
    }
  }

  bool _needsHistory(SABnzbdState state) =>
      !state.isDisposed &&
      state.instance?.enabled == true &&
      state.historyUpdatedAt == null &&
      state.historyError == null &&
      !state.historyLoading;

  void _scheduleHistoryRefresh({required bool refreshOnEntry}) {
    _historyRefreshOnEntry |= refreshOnEntry;
    if (_historyRefreshScheduled) return;
    _historyRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduleMicrotask(() {
        final refreshOnEntry = _historyRefreshOnEntry;
        _historyRefreshScheduled = false;
        _historyRefreshOnEntry = false;
        if (!mounted ||
            !_historyEntered ||
            _modalRoute?.isCurrent != true ||
            _lifecycle != AppLifecycleState.resumed) {
          return;
        }
        final states = context.read<SABnzbdConsolidatedState>().instanceStates;
        for (final state in states) {
          if (!state.isDisposed &&
              state.instance?.enabled == true &&
              (refreshOnEntry || _needsHistory(state))) {
            state.refreshHistory();
          }
        }
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router?.routeInformationProvider.removeListener(_onRouteChanged);
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aggregate = context.watch<SABnzbdConsolidatedState>();
    final enabled = aggregate.instances.isNotEmpty;
    return SABnzbdPollingScope(
      states: aggregate.instanceStates,
      routePath: '/sabnzbd',
      child: LunaScaffold(
        scaffoldKey: _scaffoldKey,
        module: LunaModule.SABNZBD,
        drawer: LunaDrawer(page: LunaModule.SABNZBD.key),
        appBar: LunaAppBar.instanceFilter(
          title: LunaModule.SABNZBD.title,
          instances: aggregate.instances,
          onInstanceSelected: (id) => SABnzbdRoutes.HOME.goInstance(
            instanceId: id,
            queryParams: {'tab': SABnzbdNavigationBar.tabKeys[_selectedPage]},
            buildTree: false,
          ),
          onAllInstancesSelected: () => SABnzbdRoutes.CONSOLIDATED.go(
            queryParams: {'tab': SABnzbdNavigationBar.tabKeys[_selectedPage]},
            buildTree: false,
          ),
          pageController: _pageController,
          scrollControllers: _scrollControllers,
          actions: enabled
              ? [
                  IconButton(
                    tooltip: 'Choose server actions',
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () async {
                      final instances = aggregate.instances;
                      final states = aggregate.instanceStates;
                      final id = await LunaInstancePickerSheet().show(
                        instances: instances,
                      );
                      if (id == null || !mounted) return;
                      final index = instances.indexWhere(
                        (instance) => instance.id == id,
                      );
                      if (index == -1) return;
                      await SABnzbdServerActions.show(context, states[index]);
                    },
                  ),
                ]
              : null,
        ),
        bottomNavigationBar: enabled
            ? SABnzbdNavigationBar(
                pageController: _pageController,
                scrollControllers: _scrollControllers,
              )
            : null,
        body: enabled
            ? LunaPageView(
                controller: _pageController,
                children: [
                  SABnzbdConsolidatedQueue(
                    refreshIndicatorKey: _refreshKeys[0],
                    scrollController: _scrollControllers[0],
                  ),
                  SABnzbdConsolidatedHistory(
                    refreshIndicatorKey: _refreshKeys[1],
                    scrollController: _scrollControllers[1],
                  ),
                ],
              )
            : LunaMessage.moduleNotEnabled(
                context: context,
                module: LunaModule.SABNZBD.title,
              ),
      ),
    );
  }
}
