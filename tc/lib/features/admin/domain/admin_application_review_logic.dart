import '../../cook/data/chef_documents_compliance.dart';
import '../../cook/data/cook_required_document_types.dart';

/// UI-facing aggregate status for a cook's verification bundle (exactly two required slots).
enum AdminApplicationOverallStatus {
  approved,
  needsResubmission,
  pending,
}

class AdminApplicationDocStats {
  const AdminApplicationDocStats({
    required this.approved,
    required this.pending,
    required this.rejected,
    required this.other,
  });

  final int approved;
  final int pending;
  final int rejected;
  final int other;

  int get total => approved + pending + rejected + other;
}

/// Effective latest row per required slot (merges legacy [national_id]/[freelancer_id] into canonical slots).
Map<String, Map<String, dynamic>> latestRequiredDocumentRowsBySlot(List<Map<String, dynamic>> rows) {
  return CookRequiredDocumentTypes.latestRowPerRequiredSlot(rows);
}

@Deprecated('Use latestRequiredDocumentRowsBySlot')
Map<String, Map<String, dynamic>> latestChefDocumentRowByType(List<Map<String, dynamic>> rows) {
  return latestRequiredDocumentRowsBySlot(rows);
}

String normalizedDocStatus(Map<String, dynamic> row) {
  final s = (row['status'] ?? '').toString().toLowerCase().trim();
  if (s == 'pending' || s == 'pending_review') return 'pending_review';
  return s;
}

/// Status chips for admin: pending, approved, rejected, needs_resubmission (DB uses `rejected`).
String adminDocumentStatusChipLabel(Map<String, dynamic>? row) {
  if (row == null) return 'Pending';
  final s = normalizedDocStatus(row);
  if (s == 'approved') {
    final noExpiry = row['no_expiry'] == true;
    if (!noExpiry && ChefDocumentsCompliance.isDocumentExpired(row['expiry_date'])) {
      return 'Expired';
    }
    return 'Approved';
  }
  if (s == 'rejected') return 'Needs resubmission';
  if (s == 'pending_review') return 'Pending';
  if (s == 'expired') return 'Expired';
  if (s.isEmpty) return 'Unknown';
  return s.replaceAll('_', ' ');
}

AdminApplicationDocStats countDocumentStatuses(Iterable<Map<String, dynamic>> latestRows) {
  var a = 0, p = 0, r = 0, o = 0;
  for (final row in latestRows) {
    final s = normalizedDocStatus(row);
    if (s == 'approved') {
      final noExpiry = row['no_expiry'] == true;
      if (!noExpiry && ChefDocumentsCompliance.isDocumentExpired(row['expiry_date'])) {
        o++;
      } else {
        a++;
      }
    } else if (s == 'rejected') {
      r++;
    } else if (s == 'pending_review') {
      p++;
    } else {
      o++;
    }
  }
  return AdminApplicationDocStats(approved: a, pending: p, rejected: r, other: o);
}

bool _slotFailsGate(Map<String, dynamic>? row) {
  if (row == null) return false;
  final s = normalizedDocStatus(row);
  if (s == 'rejected' || s == 'expired') return true;
  if (s == 'approved' &&
      row['no_expiry'] != true &&
      ChefDocumentsCompliance.isDocumentExpired(row['expiry_date'])) {
    return true;
  }
  return false;
}

bool _slotFullyApproved(Map<String, dynamic>? row) {
  if (row == null) return false;
  if (normalizedDocStatus(row) != 'approved') return false;
  if (row['no_expiry'] != true && ChefDocumentsCompliance.isDocumentExpired(row['expiry_date'])) {
    return false;
  }
  return true;
}

/// Two required documents only. See product spec (approved / pending / rejected combinations).
AdminApplicationOverallStatus computeApplicationOverallStatus(
  Map<String, Map<String, dynamic>> bySlot,
) {
  final id = bySlot[CookRequiredDocumentTypes.idDocument];
  final health = bySlot[CookRequiredDocumentTypes.healthOrKitchen];

  if (_slotFailsGate(id) || _slotFailsGate(health)) {
    return AdminApplicationOverallStatus.needsResubmission;
  }
  if (_slotFullyApproved(id) && _slotFullyApproved(health)) {
    return AdminApplicationOverallStatus.approved;
  }
  return AdminApplicationOverallStatus.pending;
}

String formatOverallStatusLabel(AdminApplicationOverallStatus s) {
  switch (s) {
    case AdminApplicationOverallStatus.approved:
      return 'Approved';
    case AdminApplicationOverallStatus.needsResubmission:
      return 'Needs resubmission';
    case AdminApplicationOverallStatus.pending:
      return 'Pending';
  }
}

bool documentRowNeedsAdminDecision(Map<String, dynamic>? row) {
  if (row == null) return false;
  return normalizedDocStatus(row) == 'pending_review';
}

bool documentRowIsLockedApproved(Map<String, dynamic>? row) {
  if (row == null) return false;
  if (normalizedDocStatus(row) != 'approved') return false;
  if (row['no_expiry'] == true) return true;
  return !ChefDocumentsCompliance.isDocumentExpired(row['expiry_date']);
}
