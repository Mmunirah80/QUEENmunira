import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
    super.phone,
    super.profileImageUrl,
    super.isVerified,
    super.role,
    super.chefAccessLevel,
    super.chefApprovalStatus,
    super.rejectionReason,
    super.isBlocked,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    AppRole? role;
    final roleStr = json['role'] as String?;
    if (roleStr == 'chef') role = AppRole.chef;
    if (roleStr == 'customer') role = AppRole.customer;
    if (roleStr == 'admin') role = AppRole.admin;
    ChefApprovalStatus? status;
    final statusStr = json['chefApprovalStatus'] as String?;
    if (statusStr == 'pending' || statusStr == 'waiting') status = ChefApprovalStatus.pending;
    if (statusStr == 'approved') status = ChefApprovalStatus.approved;
    if (statusStr == 'rejected') status = ChefApprovalStatus.rejected;
    ChefAccessLevel? al;
    final als = json['chefAccessLevel'] as String?;
    if (als == 'partialAccess') al = ChefAccessLevel.partialAccess;
    if (als == 'fullAccess') al = ChefAccessLevel.fullAccess;
    if (als == 'blockedAccess') al = ChefAccessLevel.blockedAccess;
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      role: role,
      chefAccessLevel: al,
      chefApprovalStatus: status,
      rejectionReason: json['rejectionReason'] as String?,
      isBlocked: json['isBlocked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'profileImageUrl': profileImageUrl,
      'isVerified': isVerified,
      'role': role?.name,
      'chefAccessLevel': chefAccessLevel?.name,
      'chefApprovalStatus': chefApprovalStatus?.name,
      'rejectionReason': rejectionReason,
      'isBlocked': isBlocked,
    };
  }
}
