// ============================================================
// COOK BANK ACCOUNT — Firestore (chef doc), RTL, TC theme. Loading/error/empty.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/utils/supabase_error_message.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../presentation/providers/chef_providers.dart';

class _NC {
  static const primary = AppDesignSystem.primary;
  static const primaryMid = AppDesignSystem.primaryMid;
  static const primaryLight = AppDesignSystem.primaryLight;
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const surface = AppDesignSystem.cardWhite;
  static const text = AppDesignSystem.textPrimary;
  static const textSub = AppDesignSystem.textSecondary;
  static const border = Color(0xFFE8E0F5);
}

class BankAccountScreen extends ConsumerStatefulWidget {
  const BankAccountScreen({super.key});

  @override
  ConsumerState<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends ConsumerState<BankAccountScreen> {
  bool _showIban = false;

  @override
  Widget build(BuildContext context) {
    final chefDocAsync = ref.watch(chefDocStreamProvider);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _NC.bg,
        body: chefDocAsync.when(
          data: (chefDoc) {
            final iban = chefDoc?.bankIban ?? '';
            final accountName = chefDoc?.bankAccountName ?? '';
            final hasBank = iban.isNotEmpty || accountName.isNotEmpty;

            return CustomScrollView(
              slivers: [
                _buildHeader(context),
                if (!hasBank) SliverFillRemaining(child: _buildEmpty(context)) else _buildContent(context, iban, accountName),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
          loading: () => const Center(child: LoadingWidget()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppDesignSystem.errorRed),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(userFriendlyErrorMessage(e), textAlign: TextAlign.center, style: const TextStyle(color: AppDesignSystem.errorRed)),
                ),
                const SizedBox(height: 16),
                TextButton(onPressed: () => ref.invalidate(chefDocStreamProvider), child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_NC.primary, AppDesignSystem.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 20, 24),
            child: Row(
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                const Expanded(child: Text('Bank account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_rounded, size: 64, color: _NC.primaryLight),
            const SizedBox(height: 16),
            const Text('No bank details added', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _NC.text)),
            const SizedBox(height: 8),
            const Text('Add your IBAN and account name to receive payouts.', style: TextStyle(fontSize: 14, color: _NC.textSub)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showEditSheet(context, '', ''),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add bank details'),
              style: FilledButton.styleFrom(backgroundColor: _NC.primaryMid, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, String iban, String accountName) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _NC.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _NC.border),
                boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: _NC.primaryLight, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.account_balance_rounded, color: _NC.primaryMid, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('Bank details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _NC.text)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showEditSheet(context, iban, accountName),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: _NC.primaryLight, borderRadius: BorderRadius.circular(8)),
                          child: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _NC.primaryMid)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _field('IBAN number', Row(
                    children: [
                      Expanded(
                        child: Text(
                          iban.isEmpty ? '—' : (_showIban ? iban : '${iban.length > 8 ? iban.substring(0, 4) : iban} **** **** ${iban.length > 4 ? iban.substring(iban.length - 4) : ''}'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _NC.text),
                        ),
                      ),
                      if (iban.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _showIban = !_showIban),
                          child: Icon(_showIban ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: _NC.textSub),
                        ),
                    ],
                  )),
                  const SizedBox(height: 16),
                  _field('Account holder name', Text(accountName.isEmpty ? '—' : accountName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _NC.text))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _NC.textSub)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: _NC.bg, borderRadius: BorderRadius.circular(12)),
          child: child,
        ),
      ],
    );
  }

  void _showEditSheet(BuildContext context, String currentIban, String currentName) {
    final ibanCtrl = TextEditingController(text: currentIban);
    final nameCtrl = TextEditingController(text: currentName);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: _NC.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const Text('Edit bank details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(
                controller: ibanCtrl,
                decoration: const InputDecoration(
                  labelText: 'IBAN number',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Account holder name',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () async {
                      final chefId = ref.read(authStateProvider).valueOrNull?.id;
                      if (chefId == null) {
                        Navigator.pop(ctx);
                        return;
                      }
                      final iban = ibanCtrl.text.trim();
                      if (iban.isNotEmpty && !RegExp(r'^[A-Z]{2}[0-9A-Z]{13,30}$').hasMatch(iban)) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid IBAN format')),
                        );
                        return;
                      }
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Account holder name is required')),
                        );
                        return;
                      }
                      try {
                        await ref.read(chefFirebaseDataSourceProvider).updateBankDetails(
                              chefId,
                              iban: iban.isEmpty ? null : iban,
                              accountName: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                            );
                        ref.invalidate(chefDocStreamProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        print('[CookBank] save error=$e');
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Could not save')));
                      }
                    },
                    style: FilledButton.styleFrom(backgroundColor: _NC.primaryMid),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
