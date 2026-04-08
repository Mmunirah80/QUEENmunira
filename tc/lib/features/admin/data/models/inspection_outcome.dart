/// Allowed values for [finalize_inspection_outcome] — admin records **outcome only**;
/// Penalties are computed server-side from [chef_profiles.inspection_penalty_step] (warning_1 … blocked).
enum InspectionOutcome {
  passed,
  noAnswer,
  kitchenNotClean,
  refusedInspection,
  adminTechnicalIssue,
  ;

  /// Lowercase string sent to `p_outcome` (must match Postgres checks).
  String get serverValue => switch (this) {
        InspectionOutcome.passed => 'passed',
        InspectionOutcome.noAnswer => 'no_answer',
        InspectionOutcome.kitchenNotClean => 'kitchen_not_clean',
        InspectionOutcome.refusedInspection => 'refused_inspection',
        InspectionOutcome.adminTechnicalIssue => 'admin_technical_issue',
      };

  static InspectionOutcome? tryParse(String? raw) {
    final s = raw?.trim().toLowerCase();
    return switch (s) {
      'passed' => InspectionOutcome.passed,
      'no_answer' => InspectionOutcome.noAnswer,
      'kitchen_not_clean' => InspectionOutcome.kitchenNotClean,
      'refused_inspection' => InspectionOutcome.refusedInspection,
      'admin_technical_issue' => InspectionOutcome.adminTechnicalIssue,
      _ => null,
    };
  }
}
