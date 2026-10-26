import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../application/social_controller.dart';
import '../data/social_repository.dart';
import '../domain/social_models.dart';
import 'friend_room_screen.dart';

/// Opens the Friends screen.
Future<void> openFriends(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const FriendsScreen()));

/// Sign in, your friend code, requests, waves and this week's leaderboard.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final ok = await ref.read(socialControllerProvider.notifier).signIn();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) _say('Sign-in did not work. You can try again any time.');
  }

  Future<void> _add() async {
    final result = await ref
        .read(socialControllerProvider.notifier)
        .addByCode(_code.text);
    if (!mounted) return;
    _say(switch (result) {
      RequestResult.sent => 'Request sent. They need to accept it.',
      RequestResult.alreadyFriends => 'You are friends already.',
      RequestResult.alreadyRequested => 'A request is already waiting.',
      RequestResult.yourself => 'That is your own code.',
      RequestResult.unknownCode => 'Nobody has that code. Check it and retry.',
      RequestResult.failed => 'Could not reach the server. Try again later.',
    });
    if (result == RequestResult.sent) _code.clear();
  }

  Future<void> _confirmDelete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your online data?'),
        content: const Text(
          'This removes your profile, code and friendships from the server '
          'and signs you out. Your cats and steps on this phone stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-delete'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await ref.read(socialControllerProvider.notifier).deleteOnline();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final social = ref.watch(socialControllerProvider);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: SafeArea(
        child: social.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => const Center(child: Text('Could not load friends.')),
          data: (state) {
            if (state.user == null) return _signedOut(muted);
            return _signedIn(context, state, theme, muted);
          },
        ),
      ),
    );
  }

  Widget _signedOut(TextStyle? muted) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'Walk with friends. Add friends with a code, see this week\'s steps '
        'and visit each other\'s cats.',
        style: muted,
      ),
      const SizedBox(height: 12),
      Text(
        'Walking never needs an account. Friends only see your name, your '
        'steps, your streak and your cats, never where you walk.',
        style: muted,
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        key: const Key('sign-in'),
        onPressed: _busy ? null : _signIn,
        icon: const Icon(Icons.login),
        label: Text(_busy ? 'Signing in…' : 'Sign in with Google'),
      ),
    ],
  );

  Widget _signedIn(
    BuildContext context,
    SocialState state,
    ThemeData theme,
    TextStyle? muted,
  ) {
    final controller = ref.read(socialControllerProvider.notifier);
    final code = state.me?.friendCode ?? '';
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          if (state.offline) ...[
            Text(
              'Could not reach the server. Pull down to try again.',
              style: muted,
            ),
            const SizedBox(height: 12),
          ],
          Text('Your friend code', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                code.isEmpty ? '…' : code,
                key: const Key('my-code'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  letterSpacing: 4,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Copy',
                onPressed: code.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (context.mounted) _say('Code copied.');
                      },
                icon: const Icon(Icons.copy),
              ),
              IconButton(
                tooltip: 'Share',
                onPressed: code.isEmpty
                    ? null
                    : () => SharePlus.instance.share(
                        ShareParams(
                          text:
                              'Walk with me in Catwalk! My friend code: $code',
                        ),
                      ),
                icon: const Icon(Icons.ios_share),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('friend-code'),
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'A friend\'s code',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                key: const Key('send-request'),
                onPressed: _add,
                child: const Text('Add'),
              ),
            ],
          ),
          if (state.requests.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Requests', style: theme.textTheme.titleMedium),
            for (final request in state.requests)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${request.fromName} wants to be friends'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => controller.decline(request),
                      child: const Text('Decline'),
                    ),
                    FilledButton(
                      key: Key('accept-${request.from}'),
                      onPressed: () => controller.accept(request),
                      child: const Text('Accept'),
                    ),
                  ],
                ),
              ),
          ],
          if (state.nudges.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Waves', style: theme.textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: controller.clearNudges,
                  child: const Text('Clear'),
                ),
              ],
            ),
            for (final nudge in state.nudges)
              Text('${nudge.fromName} waved at you. A walk?'),
          ],
          const SizedBox(height: 24),
          Text('This week', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (state.friends.isEmpty)
            Text(
              'No friends yet. Share your code, or type theirs above.',
              style: muted,
            )
          else
            for (final row in state.leaderboard) _Row(row: row),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                key: const Key('sign-out'),
                onPressed: controller.signOut,
                child: const Text('Sign out'),
              ),
              OutlinedButton(
                key: const Key('delete-online'),
                onPressed: _confirmDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: const Text('Delete my online data'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One line of the leaderboard.
class _Row extends StatelessWidget {
  const _Row({required this.row});

  /// The player and their place.
  final LeaderboardRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = row.profile;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: row.isMe ? CatwalkColors.card : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CatwalkColors.line),
      ),
      child: ListTile(
        key: Key('row-${profile.uid}'),
        leading: Text('${row.rank}', style: theme.textTheme.titleMedium),
        title: Text(
          row.isMe ? '${profile.displayName} (you)' : profile.displayName,
        ),
        subtitle: Text(
          '${formatNumber(profile.weekSteps)} steps · '
          '${profile.streak} day streak',
        ),
        trailing: row.isMe ? null : const Icon(Icons.chevron_right),
        onTap: row.isMe
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FriendRoomScreen(profile: profile),
                ),
              ),
      ),
    );
  }
}
