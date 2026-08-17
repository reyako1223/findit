import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'src/rust/api/findit.dart' as rust;
import 'src/rust/api/models.dart';

class FindItController extends ChangeNotifier {
  String _storageDir = '';
  bool loading = true;
  bool isDevelopment = false;
  String? error;

  Statistics statistics = const Statistics(
    lost: 0,
    found: 0,
    returned: 0,
    total: 0,
  );
  List<ItemReport> recentReports = const [];
  List<ItemReport> records = const [];
  List<MatchResult> matches = const [];

  Future<void> initialize() async {
    final directory = await getApplicationSupportDirectory();
    _storageDir = directory.path;
    await rust.cleanupLegacyData(storageDir: _storageDir);
    isDevelopment = await rust.isDevelopment();
    await refreshAll();
  }

  Future<void> refreshAll() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        rust.getStatistics(storageDir: _storageDir),
        rust.getReports(storageDir: _storageDir),
        rust.findMatches(storageDir: _storageDir),
      ]);
      statistics = results[0] as Statistics;
      recentReports = results[1] as List<ItemReport>;
      records = recentReports;
      matches = results[2] as List<MatchResult>;
    } catch (exception) {
      error = friendlyError(exception);
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<ItemReport> add(NewReportInput input) async {
    final report = await rust.addReport(storageDir: _storageDir, input: input);
    await refreshAll();
    return report;
  }

  Future<ItemReport> update(String id, UpdateReportInput input) async {
    final report = await rust.updateReport(
      storageDir: _storageDir,
      id: id,
      input: input,
    );
    await refreshAll();
    return report;
  }

  Future<void> delete(String id) async {
    await rust.deleteReport(storageDir: _storageDir, id: id);
    await refreshAll();
  }

  Future<List<ItemReport>> loadRecords({
    String? search,
    ItemStatus? status,
  }) async {
    records = await rust.getReports(
      storageDir: _storageDir,
      search: search,
      status: status,
    );
    notifyListeners();
    return records;
  }

  Future<List<MatchResult>> loadMatches({String? reportId}) async {
    matches = await rust.findMatches(
      storageDir: _storageDir,
      reportId: reportId,
    );
    notifyListeners();
    return matches;
  }

  Future<void> markReturned(MatchResult match) async {
    await rust.markAsReturned(
      storageDir: _storageDir,
      lostId: match.lostReport.id,
      foundId: match.foundReport.id,
    );
    await refreshAll();
  }

  Future<ItemReport> markReportReturned(String id) async {
    final report = await rust.markReportAsReturned(
      storageDir: _storageDir,
      id: id,
    );
    await refreshAll();
    return report;
  }

  Future<void> seedSamples() async {
    await rust.seedSampleData(storageDir: _storageDir);
    await refreshAll();
  }

  static String friendlyError(Object exception) {
    final text = exception.toString();
    return text
        .replaceFirst(RegExp(r'^(AnyhowException|Exception):\s*'), '')
        .trim();
  }
}
