import 'dart:async';

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'src/rust/api/models.dart';

class FindItApp extends StatefulWidget {
  const FindItApp({required this.controller, super.key});

  final FindItController controller;

  @override
  State<FindItApp> createState() => _FindItAppState();
}

class _FindItAppState extends State<FindItApp> {
  int selectedIndex = 0;
  int reportGeneration = 0;
  int recordsGeneration = 0;
  ReportType? initialReportType;
  ItemStatus? initialRecordsStatus;

  void selectTab(int index) {
    setState(() {
      selectedIndex = index;
      if (index == 1) {
        initialReportType = null;
        reportGeneration++;
      }
      if (index == 3) {
        initialRecordsStatus = null;
        recordsGeneration++;
      }
    });
    if (index == 0) widget.controller.refreshAll();
    if (index == 2) widget.controller.loadMatches();
    if (index == 3) widget.controller.loadRecords();
  }

  void openRecords(ItemStatus? status) {
    setState(() {
      selectedIndex = 3;
      initialRecordsStatus = status;
      recordsGeneration++;
    });
    widget.controller.loadRecords(status: status);
  }

  void openQuickReport(ReportType type) {
    setState(() {
      selectedIndex = 1;
      initialReportType = type;
      reportGeneration++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final pages = [
          HomeScreen(
            controller: widget.controller,
            onQuickReport: openQuickReport,
            onRecords: () => openRecords(null),
            onStatusRecords: (status) => openRecords(status),
            onHelp: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpAndTechnologyPage()),
            ),
          ),
          ReportHub(
            key: ValueKey(reportGeneration),
            controller: widget.controller,
            initialType: initialReportType,
            onHome: () => selectTab(0),
          ),
          MatchesScreen(
            controller: widget.controller,
            onReport: () => selectTab(1),
          ),
          RecordsScreen(
            key: ValueKey(recordsGeneration),
            controller: widget.controller,
            onReport: () => selectTab(1),
            initialStatus: initialRecordsStatus,
          ),
        ];
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey(selectedIndex),
                child: pages[selectedIndex],
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: selectTab,
            backgroundColor: Colors.white,
            indicatorColor: AppColors.primarySoft,
            height: 74,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_circle_outline_rounded),
                selectedIcon: Icon(Icons.add_circle_rounded),
                label: 'Report',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome_rounded),
                label: 'Matches',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_outline_rounded),
                selectedIcon: Icon(Icons.bookmark_rounded),
                label: 'Records',
              ),
            ],
          ),
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.controller,
    required this.onQuickReport,
    required this.onRecords,
    required this.onStatusRecords,
    required this.onHelp,
    super.key,
  });

  final FindItController controller;
  final ValueChanged<ReportType> onQuickReport;
  final VoidCallback onRecords;
  final ValueChanged<ItemStatus> onStatusRecords;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final recent = controller.recentReports.take(4).toList();
    return RefreshIndicator(
      onRefresh: controller.refreshAll,
      color: AppColors.primary,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _HomeHero(onHelp: onHelp),
          Transform.translate(
            offset: const Offset(0, -34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Lost',
                      count: controller.statistics.lost,
                      color: AppColors.lost,
                      onTap: () => onStatusRecords(ItemStatus.lost),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: StatCard(
                      label: 'Found',
                      count: controller.statistics.found,
                      color: AppColors.found,
                      onTap: () => onStatusRecords(ItemStatus.found),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: StatCard(
                      label: 'Returned',
                      count: controller.statistics.returned,
                      color: AppColors.returned,
                      onTap: () => onStatusRecords(ItemStatus.returned),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Quick report'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: QuickReportCard(
                        type: ReportType.lost,
                        onTap: () => onQuickReport(ReportType.lost),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: QuickReportCard(
                        type: ReportType.found,
                        onTap: () => onQuickReport(ReportType.found),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                HowItWorksCard(onOpenGuide: onHelp),
                const SizedBox(height: 12),
                RustPoweredCard(onOpenGuide: onHelp),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SectionTitle('Recent Reports'),
                    if (recent.isNotEmpty)
                      TextButton(
                        onPressed: onRecords,
                        child: const Text('View all'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (controller.loading && recent.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (recent.isEmpty)
                  EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No Reports Yet',
                    message:
                        'Lost or found something? Create your first report.',
                    actionLabel: 'REPORT AN ITEM',
                    onAction: () => onQuickReport(ReportType.lost),
                  )
                else
                  ...recent.map(
                    (report) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ReportCard(
                        report: report,
                        onTap: () =>
                            openReportDetails(context, controller, report),
                      ),
                    ),
                  ),
                if (controller.isDevelopment) ...[
                  const SizedBox(height: 8),
                  DevelopmentCard(
                    onSeed: () async {
                      try {
                        await controller.seedSamples();
                        if (context.mounted) {
                          showMessage(context, 'Demo data is ready.');
                        }
                      } catch (error) {
                        if (context.mounted) {
                          showMessage(
                            context,
                            FindItController.friendlyError(error),
                            error: true,
                          );
                        }
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.onHelp});

  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, Color(0xFF0B907B)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              return Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.manage_search_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Flexible(
                          child: Text(
                            'FindIt',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: 'Works completely offline',
                    child: Container(
                      height: 38,
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 10 : 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 8,
                            color: Color(0xFF8AF0C9),
                          ),
                          if (!compact) ...[
                            const SizedBox(width: 6),
                            const Text(
                              'Offline ready',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Help and app information',
                    child: IconButton(
                      onPressed: onHelp,
                      icon: const Icon(Icons.help_outline_rounded),
                      color: Colors.white,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .1),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: .18),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 36),
          const Text(
            'Hello!',
            style: TextStyle(
              color: Color(0xFFC8E8E0),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Find something\nyou’ve lost.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 33,
              height: 1.08,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 14, 8, 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withValues(alpha: .07)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: .09),
                blurRadius: 24,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 15, color: color),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                count.toString().padLeft(2, '0'),
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickReportCard extends StatelessWidget {
  const QuickReportCard({required this.type, required this.onTap, super.key});

  final ReportType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lost = type == ReportType.lost;
    final color = lost ? AppColors.lost : AppColors.found;
    return Material(
      color: lost ? AppColors.lostSoft : AppColors.foundSoft,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  lost
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'REPORT ${lost ? 'LOST' : 'FOUND'}\nITEM',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HowItWorksCard extends StatelessWidget {
  const HowItWorksCard({required this.onOpenGuide, super.key});

  final VoidCallback onOpenGuide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 17, 12, 13),
      decoration: cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.route_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'How FindIt works',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: onOpenGuide,
                child: const Text('Learn more'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _CompactGuideStep(
            number: '1',
            text: 'Report a lost or found item',
          ),
          const _CompactGuideStep(
            number: '2',
            text: 'Rust compares details and scores matches',
          ),
          const _CompactGuideStep(
            number: '3',
            text: 'Confirm the match and mark it returned',
            showLine: false,
          ),
        ],
      ),
    );
  }
}

class RustPoweredCard extends StatelessWidget {
  const RustPoweredCard({required this.onOpenGuide, super.key});

  final VoidCallback onOpenGuide;

  @override
  Widget build(BuildContext context) {
    const rustOrange = Color(0xFFCE5A2A);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF332A27), Color(0xFF594039)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: InkWell(
          onTap: onOpenGuide,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: rustOrange,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Rs',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Powered by Rust',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Structs • Enums • Result • Iterators',
                        style: TextStyle(
                          color: Color(0xFFE8D8D1),
                          fontSize: 11,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactGuideStep extends StatelessWidget {
  const _CompactGuideStep({
    required this.number,
    required this.text,
    this.showLine = true,
  });

  final String number;
  final String text;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (showLine)
                  Expanded(child: Container(width: 1, color: AppColors.line)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3, bottom: 13),
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HelpAndTechnologyPage extends StatelessWidget {
  const HelpAndTechnologyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: standardAppBar('Rust Demo Guide'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF332A27), Color(0xFF9B4525)],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Color(0xFFCE5A2A),
                    foregroundColor: Colors.white,
                    child: Text(
                      'Rs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'FindIt × Rust',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'A useful offline app that turns your Rust sessions into a working mobile demo.',
                    style: TextStyle(color: Color(0xFFF2DDD4), height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 27),
            const SectionTitle('How to use FindIt'),
            const SizedBox(height: 12),
            const GuideStepCard(
              number: '1',
              icon: Icons.add_circle_outline_rounded,
              title: 'Create a clear report',
              message:
                  'Choose Lost or Found, then enter the item name, category, color, location, and date.',
            ),
            const SizedBox(height: 10),
            const GuideStepCard(
              number: '2',
              icon: Icons.auto_awesome_rounded,
              title: 'Review smart matches',
              message:
                  'Rust compares Lost and Found reports. Matches scoring 60% or higher appear automatically.',
            ),
            const SizedBox(height: 10),
            const GuideStepCard(
              number: '3',
              icon: Icons.task_alt_rounded,
              title: 'Return the item',
              message:
                  'Open a match, confirm the details, and mark it Returned after the owner receives it.',
            ),
            const SizedBox(height: 27),
            const SectionTitle('Technology used'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: cardDecoration(radius: 20),
              child: const Column(
                children: [
                  TechnologyRow(
                    icon: Icons.flutter_dash,
                    title: 'Flutter',
                    message: 'Mobile interface, forms, and navigation',
                  ),
                  TechnologyRow(
                    icon: Icons.memory_rounded,
                    title: 'Rust 2024',
                    message: 'Validation, storage, search, and match scoring',
                  ),
                  TechnologyRow(
                    icon: Icons.data_object_rounded,
                    title: 'Local JSON',
                    message: 'Private offline reports saved on this device',
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 27),
            const SectionTitle('Rust concepts demonstrated'),
            const SizedBox(height: 12),
            const RustConceptCard(
              icon: Icons.compare_arrows_rounded,
              title: 'Ownership & borrowing',
              message:
                  'Functions borrow report slices when reading data and move owned inputs when creating records.',
              session: 'Zero to Rust Ep 02 • Book Ch 4',
            ),
            const SizedBox(height: 10),
            const RustConceptCard(
              icon: Icons.category_outlined,
              title: 'Structs, enums & pattern matching',
              message:
                  'ItemReport models the data; ReportType and ItemStatus make app states explicit and safe.',
              session: 'Zero to Rust Ep 03 • Book Ch 5–6',
            ),
            const SizedBox(height: 10),
            const RustConceptCard(
              icon: Icons.rule_rounded,
              title: 'Option & Result',
              message:
                  'Optional contact details use Option, while validation and file operations return Result errors.',
              session: 'Zero to Rust Ep 03–05 • Book Ch 6 & 9',
            ),
            const SizedBox(height: 10),
            const RustConceptCard(
              icon: Icons.filter_alt_outlined,
              title: 'Collections & iterators',
              message:
                  'Vec, HashSet, filter, map, fold, and collect power search, statistics, and smart matching.',
              session: 'Zero to Rust Ep 04 & 07 • Book Ch 8 & 13',
            ),
            const SizedBox(height: 10),
            const RustConceptCard(
              icon: Icons.account_tree_outlined,
              title: 'Modules, Cargo & testing',
              message:
                  'The Rust core is separated into models and app logic, formatted with rustfmt and covered by tests.',
              session: 'Zero to Rust Ep 08–09 • Book Ch 7 & 11',
            ),
            const SizedBox(height: 27),
            const SectionTitle('Practice companion'),
            const SizedBox(height: 12),
            const PracticeCard(),
            const SizedBox(height: 27),
            const SectionTitle('Demo Day explanation'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.record_voice_over_outlined,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 12),
                  SelectableText(
                    '“FindIt is a Flutter mobile app whose core logic is written in Rust. Rust models reports with structs and enums, validates data with Result, stores optional contact details with Option, processes records with iterators, and saves everything locally as JSON.”',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      height: 1.55,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RustConceptCard extends StatelessWidget {
  const RustConceptCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.session,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(radius: 19),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF9E8DF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFFB74D24), size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(fontSize: 11, height: 1.45),
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9E8DF),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    session,
                    style: const TextStyle(
                      color: Color(0xFF8D3A1D),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PracticeCard extends StatelessWidget {
  const PracticeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF332A27),
        borderRadius: BorderRadius.circular(21),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learn → Read → Practice',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 13),
          _PracticeRow(
            label: 'Zero to Rust',
            message:
                'Follow the session sequence and build concepts gradually.',
          ),
          _PracticeRow(
            label: 'The Rust Book',
            message: 'Read the matching chapter for deeper explanations.',
          ),
          _PracticeRow(
            label: 'Rustlings',
            message: 'Complete small exercises until every file compiles.',
            showLine: false,
          ),
        ],
      ),
    );
  }
}

class _PracticeRow extends StatelessWidget {
  const _PracticeRow({
    required this.label,
    required this.message,
    this.showLine = true,
  });

  final String label;
  final String message;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: showLine
            ? Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: .12)),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFFE87945),
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFE8D8D1),
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GuideStepCard extends StatelessWidget {
  const GuideStepCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final String number;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(radius: 19),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              Positioned(
                right: -5,
                top: -6,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Text(message, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TechnologyRow extends StatelessWidget {
  const TechnologyRow({
    required this.icon,
    required this.title,
    required this.message,
    this.showDivider = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.line))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 21, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(message, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReportHub extends StatefulWidget {
  const ReportHub({
    required this.controller,
    required this.onHome,
    this.initialType,
    super.key,
  });

  final FindItController controller;
  final ReportType? initialType;
  final VoidCallback onHome;

  @override
  State<ReportHub> createState() => _ReportHubState();
}

class _ReportHubState extends State<ReportHub> {
  ReportType? selectedType;
  ItemReport? submitted;

  @override
  void initState() {
    super.initState();
    selectedType = widget.initialType;
  }

  @override
  Widget build(BuildContext context) {
    if (submitted != null) {
      return SuccessView(
        report: submitted!,
        controller: widget.controller,
        onHome: widget.onHome,
      );
    }
    if (selectedType == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
        children: [
          const PageHeading(
            title: 'Report Item',
            subtitle: 'Create a new offline report',
          ),
          const SizedBox(height: 26),
          Text(
            'What happened?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text('Choose one option to start a quick report.'),
          const SizedBox(height: 22),
          ReportTypeChoice(
            type: ReportType.lost,
            onTap: () => setState(() => selectedType = ReportType.lost),
          ),
          const SizedBox(height: 14),
          ReportTypeChoice(
            type: ReportType.found,
            onTap: () => setState(() => selectedType = ReportType.found),
          ),
        ],
      );
    }
    return ReportForm(
      controller: widget.controller,
      type: selectedType!,
      onChangeType: () => setState(() => selectedType = null),
      onSaved: (report) => setState(() => submitted = report),
    );
  }
}

class ReportTypeChoice extends StatelessWidget {
  const ReportTypeChoice({required this.type, required this.onTap, super.key});

  final ReportType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lost = type == ReportType.lost;
    final color = lost ? AppColors.lost : AppColors.found;
    return Material(
      color: lost ? AppColors.lostSoft : AppColors.foundSoft,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(23),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  lost
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 17),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'I ${lost ? 'LOST' : 'FOUND'} AN ITEM',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      lost
                          ? 'Help the community identify it'
                          : 'Connect it with its owner',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportFormGuidance extends StatelessWidget {
  const ReportFormGuidance({required this.type, super.key});

  final ReportType type;

  @override
  Widget build(BuildContext context) {
    final lost = type == ReportType.lost;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.tips_and_updates_outlined,
            size: 21,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tip for better matches',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  lost
                      ? 'Use the exact item name and the last place you remember seeing it.'
                      : 'Describe what you actually found and the location where you picked it up.',
                  style: const TextStyle(fontSize: 11, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReportForm extends StatefulWidget {
  const ReportForm({
    required this.controller,
    required this.type,
    required this.onSaved,
    this.onChangeType,
    this.existing,
    super.key,
  });

  final FindItController controller;
  final ReportType type;
  final ValueChanged<ItemReport> onSaved;
  final VoidCallback? onChangeType;
  final ItemReport? existing;

  @override
  State<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<ReportForm> {
  static const categories = [
    'Electronics',
    'Wallet',
    'Bag',
    'Clothing',
    'School Supplies',
    'Keys',
    'Accessories',
    'Documents',
    'Others',
  ];

  final formKey = GlobalKey<FormState>();
  late final TextEditingController itemName;
  late final TextEditingController color;
  late final TextEditingController location;
  late final TextEditingController description;
  late final TextEditingController contact;
  late String category;
  late DateTime date;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final report = widget.existing;
    itemName = TextEditingController(text: report?.itemName ?? '');
    color = TextEditingController(text: report?.color ?? '');
    location = TextEditingController(text: report?.location ?? '');
    description = TextEditingController(text: report?.description ?? '');
    contact = TextEditingController(text: report?.contactInformation ?? '');
    category = report?.category ?? '';
    date = DateTime.tryParse(report?.date ?? '') ?? DateTime.now();
  }

  @override
  void dispose() {
    itemName.dispose();
    color.dispose();
    location.dispose();
    description.dispose();
    contact.dispose();
    super.dispose();
  }

  String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  Future<void> pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) setState(() => date = selected);
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (category.isEmpty) {
      showMessage(context, 'Category is required.', error: true);
      return;
    }
    setState(() => saving = true);
    final dateText = isoDate(date);
    try {
      final ItemReport report;
      if (widget.existing == null) {
        report = await widget.controller.add(
          NewReportInput(
            itemName: itemName.text,
            category: category,
            color: color.text,
            location: location.text,
            date: dateText,
            description: description.text,
            contactInformation: nullIfEmpty(contact.text),
            reportType: widget.type,
          ),
        );
      } else {
        report = await widget.controller.update(
          widget.existing!.id,
          UpdateReportInput(
            itemName: itemName.text,
            category: category,
            color: color.text,
            location: location.text,
            date: dateText,
            description: description.text,
            contactInformation: nullIfEmpty(contact.text),
          ),
        );
      }
      if (mounted) widget.onSaved(report);
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          FindItController.friendlyError(error),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lost = widget.type == ReportType.lost;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        PageHeading(
          title: widget.existing == null
              ? 'Report ${lost ? 'Lost' : 'Found'} Item'
              : 'Edit Report',
          subtitle: widget.existing == null
              ? 'Details are validated and saved by Rust'
              : widget.existing!.id,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: lost ? AppColors.lostSoft : AppColors.foundSoft,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: [
              Icon(
                lost
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: lost ? AppColors.lost : AppColors.found,
              ),
              const SizedBox(width: 10),
              Text(
                '${lost ? 'LOST' : 'FOUND'} ITEM REPORT',
                style: TextStyle(
                  color: lost ? AppColors.lost : AppColors.found,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
              const Spacer(),
              if (widget.onChangeType != null)
                TextButton(
                  onPressed: widget.onChangeType,
                  child: const Text('Change'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ReportFormGuidance(type: widget.type),
        const SizedBox(height: 12),
        const Text(
          '* Required fields',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                controller: itemName,
                validator: requiredText,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'e.g. Wallet',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: category.isEmpty ? null : category,
                validator: (value) => value == null || value.isEmpty
                    ? 'Category is required.'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
                items: categories
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => category = value ?? '',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: color,
                validator: requiredText,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Color *',
                  prefixIcon: Icon(Icons.palette_outlined),
                  hintText: 'e.g. Black',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: location,
                validator: requiredText,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Location *',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  hintText: 'e.g. Library',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: pickDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '${lost ? 'Date Lost' : 'Date Found'} *',
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    longDate(isoDate(date)),
                    style: const TextStyle(color: AppColors.ink),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: description,
                maxLength: 1000,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Details that could help identify the item...',
                  helperText: 'Distinctive marks can improve the match score.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: contact,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Contact Information (optional)',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  hintText: 'Email, phone, or pickup desk',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: saving ? null : submit,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  widget.existing == null ? 'SUBMIT REPORT' : 'SAVE CHANGES',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SuccessView extends StatelessWidget {
  const SuccessView({
    required this.report,
    required this.controller,
    required this.onHome,
    super.key,
  });

  final ItemReport report;
  final FindItController controller;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF41B596)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .24),
                    blurRadius: 32,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Report Submitted!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Your ${report.reportType == ReportType.lost ? 'lost' : 'found'} item has been added successfully.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                report.id,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => openReportDetails(context, controller, report),
              child: const Text('VIEW REPORT'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onHome,
              child: const Text('BACK TO HOME'),
            ),
          ],
        ),
      ),
    );
  }
}

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({
    required this.controller,
    required this.onReport,
    super.key,
  });

  final FindItController controller;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => controller.loadMatches(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
        children: [
          const PageHeading(
            title: 'Smart Matches',
            subtitle: 'Scores calculated by the Rust engine',
          ),
          const SizedBox(height: 14),
          MatchGuideCard(onTap: () => showMatchGuide(context)),
          const SizedBox(height: 20),
          if (controller.matches.isEmpty)
            EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'No Matches Yet',
              message:
                  'We’ll show possible matches when similar Lost and Found items are reported.',
              actionLabel: 'REPORT AN ITEM',
              onAction: onReport,
            )
          else
            ...controller.matches.map(
              (match) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: MatchCard(
                  match: match,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MatchDetailsPage(
                        controller: controller,
                        match: match,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MatchGuideCard extends StatelessWidget {
  const MatchGuideCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.calculate_outlined, color: AppColors.primary),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How is the score calculated?',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'See the five Rust scoring rules',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showMatchGuide(BuildContext context) {
  const rules = [
    ('Same item name', '35 points'),
    ('Same category', '20 points'),
    ('Same color', '15 points'),
    ('Same location', '20 points'),
    ('Description keywords', 'Up to 10 points'),
  ];
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match score guide',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Rust compares each Lost report with each Found report. Only scores of 60% or higher are suggested.',
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Column(
                children: rules
                    .map(
                      (rule) => Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.line),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 9),
                            Expanded(child: Text(rule.$1)),
                            Text(
                              rule.$2,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 17),
            const Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                MatchTierChip(label: '90–100% Excellent'),
                MatchTierChip(label: '75–89% Strong'),
                MatchTierChip(label: '60–74% Possible'),
              ],
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                Icon(Icons.memory_rounded, color: AppColors.primary, size: 19),
                SizedBox(width: 8),
                Text(
                  'CALCULATED LOCALLY BY RUST',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class MatchTierChip extends StatelessWidget {
  const MatchTierChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class MatchCard extends StatelessWidget {
  const MatchCard({required this.match, required this.onTap, super.key});

  final MatchResult match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 23),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 17,
                color: AppColors.primary,
              ),
              const SizedBox(width: 7),
              Text(
                match.quality.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.lostReport.itemName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${match.lostReport.color} · ${match.lostReport.category}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              ScoreRing(score: match.score, size: 74),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Expanded(
                  child: MatchLocation(
                    label: 'LOST',
                    location: match.lostReport.location,
                    color: AppColors.lost,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: MatchLocation(
                    label: 'FOUND',
                    location: match.foundReport.location,
                    color: AppColors.found,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              match.quality,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 13),
          OutlinedButton(onPressed: onTap, child: const Text('VIEW MATCH')),
        ],
      ),
    );
  }
}

class MatchLocation extends StatelessWidget {
  const MatchLocation({
    required this.label,
    required this.location,
    required this.color,
    super.key,
  });

  final String label;
  final String location;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          location,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({
    required this.controller,
    required this.onReport,
    this.initialStatus,
    super.key,
  });

  final FindItController controller;
  final VoidCallback onReport;
  final ItemStatus? initialStatus;

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final searchController = TextEditingController();
  Timer? debounce;
  ItemStatus? status;
  bool searching = false;

  @override
  void initState() {
    super.initState();
    status = widget.initialStatus;
  }

  @override
  void dispose() {
    debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => searching = true);
    try {
      await widget.controller.loadRecords(
        search: nullIfEmpty(searchController.text),
        status: status,
      );
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  void searchChanged(String _) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 260), load);
  }

  void clearFilters() {
    debounce?.cancel();
    searchController.clear();
    setState(() => status = null);
    load();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const PageHeading(
            title: 'Records',
            subtitle: 'All reports stored offline by Rust',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: searchController,
            onChanged: searchChanged,
            decoration: InputDecoration(
              hintText: 'Search item, location, color...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searching
                  ? const Padding(
                      padding: EdgeInsets.all(15),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : searchController.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear search',
                      onPressed: clearFilters,
                      icon: const Icon(Icons.close_rounded),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 13),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: status == null,
                  onSelected: (_) {
                    setState(() => status = null);
                    load();
                  },
                ),
                const SizedBox(width: 7),
                ...ItemStatus.values.map(
                  (value) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: FilterChip(
                      label: Text(statusLabel(value)),
                      selected: status == value,
                      onSelected: (_) {
                        setState(() => status = value);
                        load();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${widget.controller.records.length} ${widget.controller.records.length == 1 ? 'report' : 'reports'}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (widget.controller.records.isEmpty)
            EmptyState(
              icon: searchController.text.isEmpty && status == null
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_rounded,
              title: searchController.text.isEmpty && status == null
                  ? 'No Reports Yet'
                  : 'No Results Found',
              message: searchController.text.isEmpty && status == null
                  ? 'Lost or found something? Create your first report.'
                  : 'Try a different item name, location, color, category, or filter.',
              actionLabel: searchController.text.isEmpty && status == null
                  ? 'REPORT AN ITEM'
                  : 'CLEAR FILTERS',
              onAction: searchController.text.isEmpty && status == null
                  ? widget.onReport
                  : clearFilters,
            )
          else
            ...widget.controller.records.map(
              (report) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ReportCard(
                  report: report,
                  onTap: () async {
                    await openReportDetails(context, widget.controller, report);
                    await load();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ReportDetailsPage extends StatefulWidget {
  const ReportDetailsPage({
    required this.controller,
    required this.report,
    super.key,
  });

  final FindItController controller;
  final ItemReport report;

  @override
  State<ReportDetailsPage> createState() => _ReportDetailsPageState();
}

class _ReportDetailsPageState extends State<ReportDetailsPage> {
  late ItemReport report;

  @override
  void initState() {
    super.initState();
    report = widget.report;
  }

  Future<void> edit() async {
    final updated = await Navigator.of(context).push<ItemReport>(
      MaterialPageRoute(
        builder: (_) =>
            EditReportPage(controller: widget.controller, report: report),
      ),
    );
    if (updated != null && mounted) setState(() => report = updated);
  }

  Future<void> delete() async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete Report?',
      message: 'Are you sure you want to permanently delete this report?',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!confirmed) return;
    try {
      await widget.controller.delete(report.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          FindItController.friendlyError(error),
          error: true,
        );
      }
    }
  }

  Future<void> findPossibleMatches() async {
    final matches = await widget.controller.loadMatches(reportId: report.id);
    if (!mounted) return;
    if (matches.isEmpty) {
      showMessage(context, 'No match above 60% yet.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MatchResultsPage(controller: widget.controller, matches: matches),
      ),
    );
  }

  Future<void> markReturned() async {
    final confirmed = await confirmAction(
      context,
      title: 'Mark as Returned?',
      message: 'Has this item already been returned to its owner?',
      confirmLabel: 'Yes, Mark Returned',
    );
    if (!confirmed) return;

    try {
      final updated = await widget.controller.markReportReturned(report.id);
      if (!mounted) return;
      setState(() => report = updated);
      showMessage(context, 'Item marked as returned.');
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          FindItController.friendlyError(error),
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final returned = report.status == ItemStatus.returned;
    return Scaffold(
      appBar: standardAppBar('Report Details'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            DetailHero(report: report),
            const SizedBox(height: 12),
            ReturnStatusCard(
              status: report.status,
              onMarkReturned: returned ? null : markReturned,
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: cardDecoration(radius: 21),
              child: Column(
                children: [
                  DetailRow(
                    icon: Icons.sell_outlined,
                    label: 'Category',
                    value: report.category,
                  ),
                  DetailRow(
                    icon: Icons.palette_outlined,
                    label: 'Color',
                    value: report.color,
                  ),
                  DetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: report.location,
                  ),
                  DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: report.reportType == ReportType.lost
                        ? 'Date Lost'
                        : 'Date Found',
                    value: longDate(report.date),
                  ),
                  DetailRow(
                    icon: Icons.notes_rounded,
                    label: 'Description',
                    value: report.description.isEmpty
                        ? 'No description provided.'
                        : report.description,
                  ),
                  if (report.contactInformation != null)
                    DetailRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Contact Information',
                      value: report.contactInformation!,
                    ),
                  DetailRow(
                    icon: Icons.schedule_rounded,
                    label: 'Created',
                    value: longDate(report.createdAt),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (!returned) ...[
              FilledButton.icon(
                onPressed: findPossibleMatches,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('FIND POSSIBLE MATCH'),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: edit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('EDIT'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('DELETE'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: Color(0xFFF2C9C5)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReturnStatusCard extends StatelessWidget {
  const ReturnStatusCard({
    required this.status,
    required this.onMarkReturned,
    super.key,
  });

  final ItemStatus status;
  final VoidCallback? onMarkReturned;

  @override
  Widget build(BuildContext context) {
    final returned = status == ItemStatus.returned;
    final color = returned ? AppColors.primary : const Color(0xFFB86D12);
    final background = returned
        ? AppColors.primarySoft
        : const Color(0xFFFFF4E5);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  returned
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RETURN STATUS',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      returned ? 'Returned to owner' : 'Not returned yet',
                      style: TextStyle(
                        color: returned ? AppColors.primaryDark : color,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: status),
            ],
          ),
          if (!returned) ...[
            const SizedBox(height: 13),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onMarkReturned,
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text('MARK AS RETURNED'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class EditReportPage extends StatelessWidget {
  const EditReportPage({
    required this.controller,
    required this.report,
    super.key,
  });

  final FindItController controller;
  final ItemReport report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: standardAppBar('Edit Report'),
      body: SafeArea(
        child: ReportForm(
          controller: controller,
          type: report.reportType,
          existing: report,
          onSaved: (updated) {
            showMessage(context, 'Report updated successfully.');
            Navigator.of(context).pop(updated);
          },
        ),
      ),
    );
  }
}

class MatchResultsPage extends StatelessWidget {
  const MatchResultsPage({
    required this.controller,
    required this.matches,
    super.key,
  });

  final FindItController controller;
  final List<MatchResult> matches;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: standardAppBar('Possible Matches'),
      body: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: matches.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: MatchCard(
            match: matches[index],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MatchDetailsPage(
                  controller: controller,
                  match: matches[index],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MatchDetailsPage extends StatelessWidget {
  const MatchDetailsPage({
    required this.controller,
    required this.match,
    super.key,
  });

  final FindItController controller;
  final MatchResult match;

  Future<void> markReturned(BuildContext context) async {
    final confirmed = await confirmAction(
      context,
      title: 'Item Returned?',
      message: 'Has this item been successfully returned to its owner?',
      confirmLabel: 'Yes, Mark Returned',
    );
    if (!confirmed) return;
    try {
      await controller.markReturned(match);
      if (!context.mounted) return;
      showMessage(context, 'Items marked as returned!');
      Navigator.of(context).pop();
    } catch (error) {
      if (context.mounted) {
        showMessage(
          context,
          FindItController.friendlyError(error),
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: standardAppBar(match.quality),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            ComparisonCard(report: match.lostReport, type: ReportType.lost),
            const Center(
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            ComparisonCard(report: match.foundReport, type: ReportType.found),
            const SizedBox(height: 22),
            Center(child: ScoreRing(score: match.score, size: 114)),
            const SizedBox(height: 12),
            Center(
              child: Text(
                match.quality,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: cardDecoration(radius: 20),
              child: Column(
                children: match.reasons
                    .map((reason) => ReasonRow(reason: reason))
                    .toList(),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => markReturned(context),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('MARK AS RETURNED'),
            ),
          ],
        ),
      ),
    );
  }
}

class ComparisonCard extends StatelessWidget {
  const ComparisonCard({required this.report, required this.type, super.key});

  final ItemReport report;
  final ReportType type;

  @override
  Widget build(BuildContext context) {
    final lost = type == ReportType.lost;
    final color = lost ? AppColors.lost : AppColors.found;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: cardDecoration(radius: 20).copyWith(
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${lost ? 'LOST' : 'FOUND'} ITEM',
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(report.itemName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 11),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children:
                [
                      report.color,
                      report.location,
                      longDate(report.date),
                      report.category,
                    ]
                    .map(
                      (value) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          value,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }
}

class ReasonRow extends StatelessWidget {
  const ReasonRow({required this.reason, super.key});

  final MatchReason reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEDF2F1))),
      ),
      child: Row(
        children: [
          Container(
            width: 23,
            height: 23,
            decoration: BoxDecoration(
              color: reason.matched
                  ? AppColors.primary
                  : AppColors.returnedSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              reason.matched ? Icons.check_rounded : Icons.close_rounded,
              size: 14,
              color: reason.matched ? Colors.white : AppColors.muted,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              reason.label,
              style: const TextStyle(color: AppColors.ink, fontSize: 12),
            ),
          ),
          Text(
            '+${reason.points}/${reason.maxPoints}',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class DetailHero extends StatelessWidget {
  const DetailHero({required this.report, super.key});

  final ItemReport report;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(report.status);
    final second = Color.lerp(color, Colors.white, .18)!;
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, second]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusBadge(status: report.status, inverse: true),
          const SizedBox(height: 22),
          Text(
            report.itemName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -.7,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            report.id,
            style: const TextStyle(
              color: Color(0xFFDDEDE9),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .7,
            ),
          ),
        ],
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEDF2F1))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReportCard extends StatelessWidget {
  const ReportCard({required this.report, required this.onTap, super.key});

  final ItemReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          report.id,
                          style: const TextStyle(
                            color: Color(0xFF91A09E),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: report.status),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: Color(0xFF88A09C),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      report.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Color(0xFF88A09C),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    shortDate(report.date),
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  const Icon(
                    Icons.circle_outlined,
                    size: 12,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(report.color, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, this.inverse = false, super.key});

  final ItemStatus status;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: inverse
            ? Colors.white.withValues(alpha: .17)
            : statusSoftColor(status),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statusLabel(status).toUpperCase(),
        style: TextStyle(
          color: inverse ? Colors.white : color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
    );
  }
}

class ScoreRing extends StatelessWidget {
  const ScoreRing({required this.score, required this.size, super.key});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: size > 90 ? 10 : 7,
            color: AppColors.primary,
            backgroundColor: AppColors.line,
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Text.rich(
              TextSpan(
                text: '$score',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: size > 90 ? 28 : 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
                children: const [
                  TextSpan(
                    text: '%',
                    style: TextStyle(fontSize: 10, letterSpacing: 0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DevelopmentCard extends StatelessWidget {
  const DevelopmentCard({required this.onSeed, super.key});

  final VoidCallback onSeed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FAF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB7D7CF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Demo helper\nAdd matching sample reports.',
              style: TextStyle(fontSize: 11, height: 1.4),
            ),
          ),
          FilledButton(
            onPressed: onSeed,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('ADD DATA', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 330),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(icon, size: 47, color: AppColors.primary),
          ),
          const SizedBox(height: 23),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 7),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 22),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(minimumSize: const Size(190, 52)),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleLarge);
}

Future<void> openReportDetails(
  BuildContext context,
  FindItController controller,
  ItemReport report,
) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ReportDetailsPage(controller: controller, report: report),
    ),
  );
}

AppBar standardAppBar(String title) => AppBar(
  title: Text(title),
  centerTitle: true,
  backgroundColor: AppColors.background,
  surfaceTintColor: Colors.transparent,
  titleTextStyle: const TextStyle(
    color: AppColors.ink,
    fontSize: 20,
    fontWeight: FontWeight.w800,
  ),
);

BoxDecoration cardDecoration({double radius = 18}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: AppColors.line),
  boxShadow: [
    BoxShadow(
      color: AppColors.primaryDark.withValues(alpha: .045),
      blurRadius: 18,
      offset: const Offset(0, 7),
    ),
  ],
);

Color statusColor(ItemStatus status) => switch (status) {
  ItemStatus.lost => AppColors.lost,
  ItemStatus.found => AppColors.found,
  ItemStatus.returned => AppColors.returned,
};

Color statusSoftColor(ItemStatus status) => switch (status) {
  ItemStatus.lost => AppColors.lostSoft,
  ItemStatus.found => AppColors.foundSoft,
  ItemStatus.returned => AppColors.returnedSoft,
};

String statusLabel(ItemStatus status) => switch (status) {
  ItemStatus.lost => 'Lost',
  ItemStatus.found => 'Found',
  ItemStatus.returned => 'Returned',
};

String? nullIfEmpty(String text) {
  final cleaned = text.trim();
  return cleaned.isEmpty ? null : cleaned;
}

String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

const monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String shortDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
}

String longDate(String value) => shortDate(value);

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: Icon(
            danger
                ? Icons.delete_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: danger ? AppColors.danger : AppColors.primary,
            size: 40,
          ),
          title: Text(title),
          content: Text(message, textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: danger
                  ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                  : null,
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}
