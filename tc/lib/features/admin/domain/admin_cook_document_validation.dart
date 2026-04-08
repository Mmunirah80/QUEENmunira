/// Client-side rule for cook document rejection (matches [AdminActionsService.submitCookDocumentRejection]).
bool isValidCookDocumentRejectionReason(String? reason) {
  if (reason == null) return false;
  return reason.trim().length >= 5;
}
