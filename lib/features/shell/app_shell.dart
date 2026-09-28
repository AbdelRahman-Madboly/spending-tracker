import 'package:flutter/material.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/tokens.dart';
import '../../domain/spending_repository.dart';
import '../capture/capture_launcher.dart';
import '../home/home_screen.dart';
import '../home/widgets/capture_bar.dart';
import '../settings/settings_screen.dart';
import '../statistics/statistics_screen.dart';
import '../transactions/transactions_screen.dart';

/// The four tabs, in their order from the start (right) side.
enum AppTab { home, transactions, statistics, settings }

/// The app's frame (spec §4.1): a bottom [NavigationBar] with four
/// destinations and a centre-docked add FAB between السجل and الإحصائيات.
/// Tapping the FAB opens the add sheet; long-pressing it opens the capture
/// bar as a speed dial.
///
/// Every tab keeps its state: a tab is built on first visit and then only
/// taken offstage, never disposed. The tab switched to fades in (the
/// incoming half of a fade-through; the outgoing tab goes offstage at
/// once), and with animations turned off it simply appears.
class AppShell extends StatefulWidget {
  final SpendingRepository repository;
  final DateTime Function() clock;

  const AppShell({
    super.key,
    required this.repository,
    this.clock = DateTime.now,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

/// The NavigationBar's slot for the FAB's gap: destinations 0 and 1 sit on
/// the start side of it, 3 and 4 on the end side.
const _fabSlot = 2;

int _slotOf(AppTab tab) => tab.index < _fabSlot ? tab.index : tab.index + 1;
AppTab _tabAt(int slot) => AppTab.values[slot < _fabSlot ? slot : slot - 1];

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  AppTab _tab = AppTab.home;
  final Set<AppTab> _visited = {AppTab.home};

  /// The day السجل should show, set when the dashboard sends the user there.
  DateTime? _transactionsDay;

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: AppMotion.sheet,
    value: 1,
  );
  late final Animation<double> _fadeIn = CurvedAnimation(
    parent: _fade,
    curve: AppMotion.enter,
  );

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _select(AppTab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
    _fade.duration = AppMotion.of(context, AppMotion.sheet);
    _fade.forward(from: _fade.duration == Duration.zero ? 1 : 0);
  }

  void _openTransactions(DateTime day) {
    setState(() => _transactionsDay = day);
    _select(AppTab.transactions);
  }

  void _add() => openAddSheet(context, widget.repository);

  void _capture(CaptureAction action) =>
      launchCapture(context, widget.repository, action);

  Future<void> _openSpeedDial() async {
    final action = await showModalBottomSheet<CaptureAction>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          key: const Key('capture-speed-dial'),
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: CaptureBar(
            onAction: (action) => Navigator.of(sheetContext).pop(action),
          ),
        ),
      ),
    );
    if (action != null && mounted) _capture(action);
  }

  Widget _buildTab(AppTab tab) => switch (tab) {
    AppTab.home => HomeScreen(
      repository: widget.repository,
      clock: widget.clock,
      onAdd: _add,
      onCapture: _capture,
      onOpenStatistics: () => _select(AppTab.statistics),
      onOpenTransactions: _openTransactions,
    ),
    AppTab.transactions => TransactionsScreen(
      repository: widget.repository,
      clock: widget.clock,
      initialDay: _transactionsDay,
    ),
    AppTab.statistics => StatisticsScreen(repository: widget.repository),
    AppTab.settings => SettingsScreen(repository: widget.repository),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          for (final tab in AppTab.values)
            if (_visited.contains(tab))
              Offstage(
                offstage: tab != _tab,
                child: TickerMode(
                  enabled: tab == _tab,
                  child: FadeTransition(
                    opacity: tab == _tab
                        ? _fadeIn
                        : const AlwaysStoppedAnimation(1),
                    child: KeyedSubtree(
                      key: ValueKey(tab),
                      child: _buildTab(tab),
                    ),
                  ),
                ),
              ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // No tooltip: a tooltip takes the long press for itself, and here the
      // long press opens the speed dial. The label goes to semantics.
      floatingActionButton: Semantics(
        label: 'إضافة مصروف',
        onLongPressHint: 'طرق التسجيل',
        child: GestureDetector(
          onLongPress: _openSpeedDial,
          child: FloatingActionButton(
            key: const Key('add-fab'),
            onPressed: _add,
            child: const Icon(AppIcons.add),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _slotOf(_tab),
        onDestinationSelected: (slot) {
          if (slot != _fabSlot) _select(_tabAt(slot));
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(AppIcons.navHome),
            selectedIcon: Icon(AppIcons.navHome, fill: 1),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.navTransactions),
            selectedIcon: Icon(AppIcons.navTransactions, fill: 1),
            label: 'السجل',
          ),
          // The FAB's gap: an empty slot the FAB docks over.
          SizedBox(width: 72),
          NavigationDestination(
            icon: Icon(AppIcons.navStats),
            selectedIcon: Icon(AppIcons.navStats, fill: 1),
            label: 'الإحصائيات',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.navSettings),
            selectedIcon: Icon(AppIcons.navSettings, fill: 1),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}
