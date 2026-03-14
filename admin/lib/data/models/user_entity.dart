import 'package:equatable/equatable.dart';

enum AppRole { chef, customer }

enum ChefApprovalStatus { pending, approved, rejected }

/// Matches TC Firestore users collection.
class UserEntity extends Equatable {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String? profileImageUrl;
  final bool isVerified;
  final AppRole? role;
  final ChefApprovalStatus? chefApprovalStatus;
  final String? rejectionReason;

  const UserEntity({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.profileImageUrl,
    this.isVerified = false,
    this.role,
    this.chefApprovalStatus,
    this.rejectionReason,
  });

  bool get isChef => role == AppRole.chef;
  bool get isCustomer => role == AppRole.customer;
  bool get isChefApproved => role == AppRole.chef && chefApprovalStatus == ChefApprovalStatus.approved;
  bool get isChefRejected => role == AppRole.chef && chefApprovalStatus == ChefApprovalStatus.rejected;
  bool get isChefPending => role == AppRole.chef && chefApprovalStatus == ChefApprovalStatus.pending;

  @override
  List<Object?> get props => [id, email, name, phone, profileImageUrl, isVerified, role, chefApprovalStatus, rejectionReason];
}
