import 'user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
    super.phone,
    super.profileImageUrl,
    super.isVerified,
    super.role,
    super.chefApprovalStatus,
    super.rejectionReason,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    AppRole? role;
    final roleStr = json['role'] as String?;
    if (roleStr == 'chef') role = AppRole.chef;
    if (roleStr == 'customer') role = AppRole.customer;
    ChefApprovalStatus? status;
    final statusStr = json['chefApprovalStatus'] as String?;
    if (statusStr == 'pending') status = ChefApprovalStatus.pending;
    if (statusStr == 'approved') status = ChefApprovalStatus.approved;
    if (statusStr == 'rejected') status = ChefApprovalStatus.rejected;
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      role: role,
      chefApprovalStatus: status,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }
}
