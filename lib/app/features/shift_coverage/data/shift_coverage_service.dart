import '../../../core/network/api_client.dart';
import '../models/coverage_user.dart';
import '../models/shift_coverage.dart';

class ShiftCoveragePage {
  final List<ShiftCoverage> coverages;
  final int currentPage;
  final int lastPage;

  const ShiftCoveragePage({
    required this.coverages,
    required this.currentPage,
    required this.lastPage,
  });

  bool get hasMore => currentPage < lastPage;
}

class ShiftCoverageService {
  final ApiClient _apiClient;

  ShiftCoverageService(this._apiClient);

  Future<List<CoverageUser>> getUsers() async {
    final response = await _apiClient.dio.get('/api/mobile/shift-coverages/users');
    final data = (response.data as Map<String, dynamic>)['data'] as List? ?? [];
    return data
        .map((e) => CoverageUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ShiftCoveragePage> getCoverages({int page = 1}) async {
    final response = await _apiClient.dio.get(
      '/api/mobile/shift-coverages',
      queryParameters: {'page': page},
    );
    final body = response.data as Map<String, dynamic>;
    final data = (body['data'] as List? ?? []);
    final meta = (body['meta'] as Map<String, dynamic>?) ?? const {};

    return ShiftCoveragePage(
      coverages: data
          .map((e) => ShiftCoverage.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentPage: (meta['current_page'] as int?) ?? page,
      lastPage: (meta['last_page'] as int?) ?? page,
    );
  }

  Future<void> startCoverage({
    required List<int> coversUserIds,
    DateTime? endsAt,
    String? reason,
  }) async {
    await _apiClient.dio.post('/api/mobile/shift-coverages', data: {
      'covers_user_ids': coversUserIds,
      if (endsAt != null) 'ends_at': endsAt.toIso8601String(),
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  Future<void> finishCoverage(int id) async {
    await _apiClient.dio.patch('/api/mobile/shift-coverages/$id/finish');
  }
}
