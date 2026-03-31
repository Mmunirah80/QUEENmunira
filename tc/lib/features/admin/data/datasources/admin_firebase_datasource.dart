import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../auth/data/models/user_model.dart';

class AdminFirebaseDataSource {
  final FirebaseFirestore _firestore;

  AdminFirebaseDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ─── Chef approval ───────────────────────────────────────────────────

  /// Real-time stream of chefs whose status is 'pending'.
  Stream<List<UserModel>> watchPendingChefs() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'chef')
        .where('chefApprovalStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => UserModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Fetches all chefs regardless of status.
  Future<List<UserModel>> getAllChefs() async {
    final snap = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'chef')
        .get();
    return snap.docs
        .map((doc) => UserModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  /// Approves a chef account.
  Future<void> approveChef(String chefId) {
    return _firestore.collection('users').doc(chefId).update({
      'chefApprovalStatus': 'approved',
    });
  }

  /// Rejects a chef account and stores the [reason].
  Future<void> rejectChef(String chefId, {required String reason}) {
    return _firestore.collection('users').doc(chefId).update({
      'chefApprovalStatus': 'rejected',
      'rejectionReason': reason,
    });
  }

  // ─── Users ───────────────────────────────────────────────────────────

  /// Fetches all customers.
  Future<List<UserModel>> getAllCustomers() async {
    final snap = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'customer')
        .get();
    return snap.docs
        .map((doc) => UserModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }
}
