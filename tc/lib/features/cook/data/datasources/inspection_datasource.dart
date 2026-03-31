/// Inspection requests for admin/chef. Stubbed until backend is available.
class InspectionDataSource {
  Stream<Map<String, dynamic>?> watchCurrentRequest(String chefId) {
    return Stream.value(null);
  }

  Future<void> acceptRequest(String chefId) async {
    return;
  }

  Future<void> rejectRequest(String chefId) async {
    return;
  }

  Future<void> clearCurrentRequest(String chefId) async {
    return;
  }
}
