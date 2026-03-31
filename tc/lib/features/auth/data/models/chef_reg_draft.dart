/// Data collected on the account step of chef registration; passed to documents step.
class ChefRegDraft {
  final String name;
  final String email;
  final String? phone;
  final String password;

  const ChefRegDraft({
    required this.name,
    required this.email,
    this.phone,
    required this.password,
  });
}
