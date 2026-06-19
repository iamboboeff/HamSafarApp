import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamsafar/core/i18n/l10n.dart';

import '../../models/user_profile.dart';
import '../../state/app_state.dart';
import '../../theme/app_text.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';

/// Lets the user review and lift the blocks they've placed (App Store
/// Guideline 1.2 — blocking must be reversible and discoverable). Reached from
/// Приватность и безопасность.
class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  List<UserProfile> _blocked = const [];
  bool _isLoading = true;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final blocked =
          await ref.read(supabaseServiceProvider).fetchBlockedProfiles();
      if (!mounted) return;
      setState(() {
        _blocked = blocked;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unblock(UserProfile user) async {
    final id = user.backendId;
    if (id == null || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(blockedUserIdsProvider.notifier).unblock(id);
      if (!mounted) return;
      setState(() {
        _blocked = _blocked.where((u) => u.backendId != id).toList();
        _busy.remove(id);
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(trf('{name} разблокирован.', {'name': user.name})),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy.remove(id));
      messenger.showSnackBar(
        SnackBar(
          content:
              Text(tr('Не удалось разблокировать. Попробуйте ещё раз.')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(tr('Заблокированные пользователи'))),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_blocked.isEmpty)
            _buildEmpty(context)
          else
            ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              itemCount: _blocked.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildRow(_blocked[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 44, color: context.secondaryText),
            const SizedBox(height: 14),
            Text(
              tr('Вы никого не заблокировали'),
              style: HSText.headline,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              tr('Заблокировать пользователя можно из его профиля или чата. '
                  'Заблокированные не видят ваши поездки и сообщения.'),
              style: HSText.subheadline.copyWith(color: context.secondaryText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(UserProfile user) {
    final isBusy = user.backendId != null && _busy.contains(user.backendId);
    return GlassCard(
      child: Row(
        children: [
          ProfileAvatar(
            initials: user.initials,
            avatarBytes: user.avatarBytes,
            avatarUrl: user.avatarUrl,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.name,
              style: HSText.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: isBusy ? null : () => _unblock(user),
            child: Text(isBusy ? '…' : tr('Разблокировать')),
          ),
        ],
      ),
    );
  }
}
