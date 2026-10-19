import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/system/preferences/sabnzbd.dart';
import 'package:lunasea/modules/sabnzbd.dart';
import 'package:lunasea/modules/sabnzbd/widgets/polling_scope.dart';
import 'package:lunasea/modules/sabnzbd/widgets/server_actions.dart';
import 'package:lunasea/router/routes/sabnzbd.dart';

class SABnzbdRoute extends StatefulWidget {
  final LunaServiceInstance? instance;
  final bool showDrawer;
  final int? initialPage;

  const SABnzbdRoute({
    super.key,
    this.instance,
    this.showDrawer = true,
    this.initialPage,
  });

  @override
  State<SABnzbdRoute> createState() => _State();
}

class _State extends State<SABnzbdRoute> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scrollControllers = List.generate(2, (_) => ScrollController());
  final _refreshKeys = List.generate(
    2,
    (_) => GlobalKey<RefreshIndicatorState>(),
  );
  late final LunaPageController _pageController;
  late int _currentPage;
  SABnzbdState? _state;
  GoRouter? _router;
  ModalRoute<dynamic>? _modalRoute;
  bool _routeVisible = true;
  bool _historyEntered = false;
  bool _historyRefreshScheduled = false;
  bool _historyRefreshOnEntry = false;
  late AppLifecycleState _lifecycle;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    _lifecycle = binding.lifecycleState ?? AppLifecycleState.resumed;
    binding.addObserver(this);
    _currentPage =
        (widget.initialPage ?? SABnzbdPreferences.NAVIGATION_INDEX.read())
            .clamp(0, 1)
            .toInt();
    _pageController = LunaPageController(initialPage: _currentPage)
      ..addListener(_pageChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _modalRoute = ModalRoute.of(context);
    final state = context.watch<SABnzbdState>();
    if (!identical(_state, state)) {
      _state = state;
      _historyEntered = false;
    }
    final router = GoRouter.maybeOf(context);
    if (!identical(_router, router)) {
      _router?.routeInformationProvider.removeListener(_onRouteChanged);
      _router = router;
      _router?.routeInformationProvider.addListener(_onRouteChanged);
    }
    _onRouteChanged();
  }

  @override
  void didUpdateWidget(covariant SABnzbdRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPage != oldWidget.initialPage &&
        widget.initialPage != null) {
      final page = widget.initialPage!.clamp(0, 1).toInt();
      _selectPage(page);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.initialPage?.clamp(0, 1) != page) return;
        if (_pageController.hasClients) _pageController.jumpToPage(page);
      });
    }
  }

  void _pageChanged() {
    if (_pageController.hasClients) {
      _selectPage((_pageController.page ?? _currentPage).round());
    }
  }

  void _selectPage(int page) {
    if (page == _currentPage) return;
    _currentPage = page;
    _reconcileHistoryEntry();
  }

  void _onRouteChanged() {
    final owner = _state?.instance;
    final modalRoute = _modalRoute;
    _routeVisible =
        modalRoute?.isCurrent == true &&
        (modalRoute is PopupRoute ||
            modalRoute is ModalSheetRoute ||
            _router == null ||
            (owner != null &&
                _router!.routeInformationProvider.value.uri.path ==
                    '/sabnzbd/${owner.id}'));
    _reconcileHistoryEntry();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _onRouteChanged();
  }

  void _openInstance(String? instanceId) {
    final query = {'tab': SABnzbdNavigationBar.tabKeys[_currentPage]};
    final modalRoute = _modalRoute;
    if (modalRoute != null &&
        (modalRoute is PopupRoute || modalRoute is ModalSheetRoute) &&
        modalRoute.isCurrent) {
      modalRoute.navigator!.pop();
    }
    if (instanceId == null) {
      SABnzbdRoutes.CONSOLIDATED.go(queryParams: query, buildTree: false);
    } else {
      SABnzbdRoutes.HOME.goInstance(
        instanceId: instanceId,
        queryParams: query,
        buildTree: false,
      );
    }
  }

  void _reconcileHistoryEntry() {
    final state = _state;
    final entered =
        _routeVisible &&
        _lifecycle == AppLifecycleState.resumed &&
        _currentPage == 1 &&
        state != null &&
        state.instance?.enabled == true &&
        !state.isDisposed;
    final newlyEntered = entered && !_historyEntered;
    _historyEntered = entered;
    if (entered && (newlyEntered || _needsHistory(state))) {
      _scheduleHistoryRefresh(refreshOnEntry: newlyEntered);
    }
  }

  bool _needsHistory(SABnzbdState state) =>
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
        final state = _state;
        if (state != null &&
            state.instance?.enabled == true &&
            !state.isDisposed &&
            (refreshOnEntry || _needsHistory(state))) {
          state.refreshHistory();
        }
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router?.routeInformationProvider.removeListener(_onRouteChanged);
    _pageController.removeListener(_pageChanged);
    _pageController.dispose();
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SABnzbdState>();
    final owner = state.instance;
    final enabled = owner?.enabled == true;
    final scaffold = LunaScaffold(
      scaffoldKey: _scaffoldKey,
      body: enabled
          ? LunaPageView(
              controller: _pageController,
              children: [
                SABnzbdQueue(
                  key: ValueKey((state, 'queue')),
                  refreshIndicatorKey: _refreshKeys[0],
                  scrollController: _scrollControllers[0],
                ),
                SABnzbdHistory(
                  key: ValueKey((state, 'history')),
                  refreshIndicatorKey: _refreshKeys[1],
                  scrollController: _scrollControllers[1],
                ),
              ],
            )
          : LunaMessage.moduleNotEnabled(
              context: context,
              module: LunaModule.SABNZBD.title,
            ),
      drawer: widget.showDrawer
          ? LunaDrawer(page: LunaModule.SABNZBD.key)
          : null,
      appBar: LunaAppBar.instanceFilter(
        title: owner?.displayName ?? LunaModule.SABNZBD.title,
        useDrawer: widget.showDrawer,
        hideLeading: !widget.showDrawer,
        instances: context.watch<ProfilesStore>().active.enabledInstances(
          LunaModule.SABNZBD,
        ),
        selectedInstanceId: owner?.id,
        onInstanceSelected: _openInstance,
        onAllInstancesSelected: () => _openInstance(null),
        actions: [
          if (enabled && state.status != null && !state.queueStale)
            const SABnzbdAppBarStats(),
          if (enabled)
            LunaIconButton(
              icon: Icons.more_vert_rounded,
              onPressed: () => SABnzbdServerActions.show(context, state),
            ),
        ],
        pageController: _pageController,
        scrollControllers: _scrollControllers,
      ),
      bottomNavigationBar: enabled
          ? SABnzbdNavigationBar(
              pageController: _pageController,
              scrollControllers: _scrollControllers,
              updateRoute:
                  _modalRoute is! PopupRoute && _modalRoute is! ModalSheetRoute,
            )
          : null,
      extendBodyBehindAppBar: false,
      extendBody: false,
    );
    if (!enabled) return scaffold;
    return SABnzbdPollingScope(
      states: [state],
      routePath: '/sabnzbd/${owner!.id}',
      child: scaffold,
    );
  }
}
