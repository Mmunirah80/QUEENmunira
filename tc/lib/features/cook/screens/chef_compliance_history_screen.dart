import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/presentation/providers/auth_provider.dart';
import '../data/datasources/inspection_datasource.dart';

/// Cook-facing list of past inspection sessions from [inspection_calls].
class ChefComplianceHistoryScreen extends ConsumerStatefulWidget {
  const ChefComplianceHistoryScreen({super.key});

  @override
  ConsumerState<ChefComplianceHistoryScreen> createState() => _ChefComplianceHistoryScreenState();
}

class _ChefComplianceHistoryScreenState extends ConsumerState<ChefComplianceHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = ref.read(authStateProvider).valueOrNull?.id;
    if (uid == null || uid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Not signed in';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(inspectionDataSourceProvider).fetchInspectionHistoryForChef(chefId: uid, limit: 40);
      if (!mounted) return;
      setState(() {
        _rows = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  static String _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat.yMMMd().add_jm().format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection history'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : _rows.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No inspection sessions yet.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final r = _rows[i];
                        final st = (r['status'] ?? '—').toString();
                        final oc = (r['outcome'] ?? '').toString();
                        final ra = (r['result_action'] ?? '').toString();
                        final counted = r['counted_as_violation'] == true;
                        return Card(
                          child: ListTile(
                            title: Text(
                              oc.isNotEmpty ? oc : (ra.isNotEmpty ? ra : st),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              'Status: $st · ${_fmt(r['created_at']?.toString())}\n'
                              'Finalized: ${_fmt(r['finalized_at']?.toString())}\n'
                              'Counted as violation: ${counted ? 'yes' : 'no'}',
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.35),
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
    );
  }
}
