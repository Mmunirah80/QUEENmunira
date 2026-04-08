import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static contract tests: admin moderation must call the expected RPCs / tables
/// (no live Supabase).
void main() {
  final dsPath = File('lib/features/admin/data/datasources/admin_supabase_datasource.dart');

  test('setChefDocumentStatus uses apply_chef_document_review RPC with document params', () {
    expect(dsPath.existsSync(), isTrue);
    final s = dsPath.readAsStringSync();
    final idx = s.indexOf('setChefDocumentStatus');
    expect(idx, greaterThan(-1));
    final window = s.substring(idx, idx + 600);
    expect(window.contains("'apply_chef_document_review'"), isTrue);
    expect(window.contains('p_document_id'), isTrue);
    expect(window.contains('p_status'), isTrue);
    expect(window.contains('p_rejection_reason'), isTrue);
  });

  test('adminChefTakeEnforcementAction uses admin_chef_take_enforcement_action RPC', () {
    final s = dsPath.readAsStringSync();
    final idx = s.indexOf('adminChefTakeEnforcementAction');
    expect(idx, greaterThan(-1));
    final window = s.substring(idx, idx + 400);
    expect(window.contains("'admin_chef_take_enforcement_action'"), isTrue);
    expect(window.contains('p_cook_id'), isTrue);
  });

  test('getAdminUserDetail returns safe error map for empty id (no network)', () {
    final s = dsPath.readAsStringSync();
    final idx = s.indexOf('getAdminUserDetail');
    expect(idx, greaterThan(-1));
    final window = s.substring(idx, idx + 200);
    expect(window.contains("if (id.isEmpty) return {'error': 'invalid_id'}"), isTrue);
  });

  test('setReelHiddenForAdmin updates reels.is_hidden by id', () {
    final s = dsPath.readAsStringSync();
    final idx = s.indexOf('setReelHiddenForAdmin');
    expect(idx, greaterThan(-1));
    final window = s.substring(idx, idx + 250);
    expect(window.contains(".from('reels')"), isTrue);
    expect(window.contains('is_hidden'), isTrue);
  });
}
