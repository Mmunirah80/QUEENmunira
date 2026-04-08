import '../../admin/domain/admin_application_review_logic.dart';
import '../data/cook_required_document_types.dart';

/// Product-facing status derived from the latest row per required document slot.
typedef CookOnboardingApplicationStatus = AdminApplicationOverallStatus;

CookOnboardingApplicationStatus cookOnboardingStatusFromDocumentRows(
  List<Map<String, dynamic>> rows,
) {
  final bySlot = latestRequiredDocumentRowsBySlot(rows);
  return computeApplicationOverallStatus(bySlot);
}

String cookOnboardingStatusDescription(CookOnboardingApplicationStatus s) {
  switch (s) {
    case AdminApplicationOverallStatus.approved:
      return 'Both documents approved';
    case AdminApplicationOverallStatus.needsResubmission:
      return 'Needs resubmission';
    case AdminApplicationOverallStatus.pending:
      return 'Pending review';
  }
}
