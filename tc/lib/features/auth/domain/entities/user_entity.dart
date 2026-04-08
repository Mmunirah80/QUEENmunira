import 'package:equatable/equatable.dart';

/// User role in the marketplace.
enum AppRole { chef, customer, admin }

/// Legacy display enum; routing uses [ChefAccessLevel] from Supabase.
enum ChefApprovalStatus { pending, approved, rejected }

/// Chef shell / marketplace access (from [chef_profiles.access_level] — server authority).
enum ChefAccessLevel {
  partialAccess,
  fullAccess,
  blockedAccess,
}

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String? profileImageUrl;
  final bool isVerified;
  final AppRole? role;
  /// Server-driven access level for chefs (replaces ad-hoc [ChefApprovalStatus] for routing).
  final ChefAccessLevel? chefAccessLevel;
  /// Legacy / display; prefer [chefAccessLevel] for gates.
  final ChefApprovalStatus? chefApprovalStatus;
  final String? rejectionReason;
  final bool isBlocked;

  const UserEntity({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.profileImageUrl,
    this.isVerified = false,
    this.role,
    this.chefAccessLevel,
    this.chefApprovalStatus,
    this.rejectionReason,
    this.isBlocked = false,
  });

  bool get isChef => role == AppRole.chef;
  bool get isCustomer => role == AppRole.customer;
  bool get isAdmin => role == AppRole.admin;

  bool get isChefFullAccess =>
      role == AppRole.chef && chefAccessLevel == ChefAccessLevel.fullAccess;

  bool get isChefPartialAccess =>
      role == AppRole.chef && chefAccessLevel == ChefAccessLevel.partialAccess;

  bool get isChefBlockedAccess =>
      role == AppRole.chef && chefAccessLevel == ChefAccessLevel.blockedAccess;

  /// Legacy: pending in the old enum sense (partial shell).
  bool get isChefPending =>
      role == AppRole.chef &&
      (chefApprovalStatus == null || chefApprovalStatus == ChefApprovalStatus.pending);

  /// Deprecated for document review — use [isChefBlockedAccess] / moderation flags.
  bool get isChefApproved =>
      role == AppRole.chef && chefApprovalStatus == ChefApprovalStatus.approved;

  bool get isChefRejected =>
      role == AppRole.chef && chefApprovalStatus == ChefApprovalStatus.rejected;

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        phone,
        profileImageUrl,
        isVerified,
        role,
        chefAccessLevel,
        chefApprovalStatus,
        rejectionReason,
        isBlocked,
      ];
}
