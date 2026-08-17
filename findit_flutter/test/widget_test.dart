import 'package:findit_flutter/app_controller.dart';
import 'package:findit_flutter/app_theme.dart';
import 'package:findit_flutter/findit_app.dart';
import 'package:findit_flutter/main.dart';
import 'package:findit_flutter/src/rust/api/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('splash screen identifies FindIt', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildFindItTheme(), home: const SplashScreen()),
    );

    expect(find.text('FindIt'), findsOneWidget);
    expect(find.text('Smart Lost & Found Matcher'), findsOneWidget);
    expect(find.byIcon(Icons.manage_search_rounded), findsOneWidget);
  });

  testWidgets('returned status uses a readable badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFindItTheme(),
        home: const Scaffold(body: StatusBadge(status: ItemStatus.returned)),
      ),
    );

    expect(find.text('RETURNED'), findsOneWidget);
  });

  testWidgets('return status indicator can mark an active item', (
    tester,
  ) async {
    var marked = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFindItTheme(),
        home: Scaffold(
          body: ReturnStatusCard(
            status: ItemStatus.found,
            onMarkReturned: () => marked = true,
          ),
        ),
      ),
    );

    expect(find.text('Not returned yet'), findsOneWidget);
    expect(find.text('FOUND'), findsOneWidget);
    await tester.tap(find.text('MARK AS RETURNED'));
    expect(marked, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFindItTheme(),
        home: const Scaffold(
          body: ReturnStatusCard(
            status: ItemStatus.returned,
            onMarkReturned: null,
          ),
        ),
      ),
    );
    expect(find.text('Returned to owner'), findsOneWidget);
    expect(find.text('RETURNED'), findsOneWidget);
    expect(find.text('MARK AS RETURNED'), findsNothing);
  });

  testWidgets('match card header reflects the Rust quality', (tester) async {
    const lost = ItemReport(
      id: 'LST-0001',
      itemName: 'Wallet',
      category: 'Wallet',
      color: 'Black',
      location: 'Library',
      date: '2026-08-11',
      description: 'Black wallet',
      reportType: ReportType.lost,
      status: ItemStatus.lost,
      createdAt: '2026-08-11T00:00:00Z',
    );
    const found = ItemReport(
      id: 'FND-0001',
      itemName: 'Wallet',
      category: 'Wallet',
      color: 'Black',
      location: 'Library',
      date: '2026-08-11',
      description: 'Found black wallet',
      reportType: ReportType.found,
      status: ItemStatus.found,
      createdAt: '2026-08-11T00:01:00Z',
    );
    const match = MatchResult(
      lostReport: lost,
      foundReport: found,
      score: 98,
      quality: 'Excellent Match',
      reasons: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFindItTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MatchCard(match: match, onTap: _noop),
          ),
        ),
      ),
    );

    expect(find.text('EXCELLENT MATCH'), findsOneWidget);
    expect(find.text('POSSIBLE MATCH'), findsNothing);
  });

  testWidgets('demo guide maps the Rust learning sessions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFindItTheme(),
        home: const HelpAndTechnologyPage(),
      ),
    );

    expect(find.text('How to use FindIt'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Technology used'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Technology used'), findsOneWidget);
    expect(find.text('Local JSON'), findsOneWidget);

    final concepts = find.text('Rust concepts demonstrated');
    for (var step = 0; step < 6 && concepts.evaluate().isEmpty; step++) {
      await tester.drag(find.byType(ListView), const Offset(0, -140));
      await tester.pumpAndSettle();
    }

    expect(concepts, findsOneWidget);
    expect(find.text('Ownership & borrowing'), findsOneWidget);
  });

  testWidgets('dashboard counters open their filtered records list', (
    tester,
  ) async {
    for (final status in ItemStatus.values) {
      final controller = _FakeFindItController();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildFindItTheme(),
          home: FindItApp(key: ValueKey(status), controller: controller),
        ),
      );

      final label = statusLabel(status);
      await tester.tap(find.widgetWithText(StatCard, label.toUpperCase()));
      await tester.pumpAndSettle();

      expect(controller.requestedStatus, status);
      expect(find.text('Records'), findsWidgets);
      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, label),
      );
      expect(chip.selected, isTrue);
    }
  });

  testWidgets('home header remains usable on a compact phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFindItTheme(),
        home: Scaffold(
          body: HomeScreen(
            controller: FindItController(),
            onQuickReport: (_) {},
            onRecords: _noop,
            onStatusRecords: (_) {},
            onHelp: _noop,
          ),
        ),
      ),
    );

    expect(find.text('FindIt'), findsOneWidget);
    expect(find.byTooltip('Help and app information'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}

class _FakeFindItController extends FindItController {
  ItemStatus? requestedStatus;

  @override
  Future<List<ItemReport>> loadRecords({
    String? search,
    ItemStatus? status,
  }) async {
    requestedStatus = status;
    records = const [];
    return records;
  }
}
