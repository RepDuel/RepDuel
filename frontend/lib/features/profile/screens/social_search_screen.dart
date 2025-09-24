// frontend/lib/features/profile/screens/social_search_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/social_user.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/providers/social_search_provider.dart';
import '../../../widgets/loading_spinner.dart';

final _pendingFollowActionsProvider =
    StateProvider.autoDispose<Set<String>>((ref) => <String>{});

class SocialSearchScreen extends ConsumerStatefulWidget {
  const SocialSearchScreen({super.key});

  @override
  ConsumerState<SocialSearchScreen> createState() => _SocialSearchScreenState();
}

class _SocialSearchScreenState extends ConsumerState<SocialSearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleFollow(SocialUserSummary user) async {
    if (user.isSelf) {
      return;
    }

    final notifier = ref.read(_pendingFollowActionsProvider.notifier);
    notifier.update((state) => {...state, user.id});

    try {
      final client = ref.read(privateHttpClientProvider);
      if (user.isFollowing) {
        await client.delete('/users/${user.id}/follow');
      } else {
        await client.post('/users/${user.id}/follow');
      }
      final query = ref.read(socialSearchQueryProvider);
      ref.invalidate(socialSearchResultsProvider(query));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update follow status: $error')),
        );
      }
    } finally {
      notifier.update((state) {
        final updated = {...state};
        updated.remove(user.id);
        return updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = ref.watch(socialSearchQueryProvider);
    final resultsAsync = ref.watch(socialSearchResultsProvider(query));
    final pending = ref.watch(_pendingFollowActionsProvider);

    if (_controller.text != query) {
      _controller.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Find Athletes'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: (value) =>
                  ref.read(socialSearchQueryProvider.notifier).state = value,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                // was: Colors.white.withOpacity(0.06)
                fillColor: Colors.white.withValues(alpha: 0.06),
                hintText: 'Search by username or display name',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _controller.clear();
                          ref.read(socialSearchQueryProvider.notifier).state =
                              '';
                        },
                        icon: const Icon(Icons.clear, color: Colors.white54),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              loading: () => const Center(child: LoadingSpinner()),
              error: (error, _) => _SearchError(
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(socialSearchResultsProvider(query)),
              ),
              data: (results) {
                final trimmed = query.trim();
                if (trimmed.isEmpty) {
                  return const _SearchPlaceholder();
                }

                if (results.items.isEmpty) {
                  return const _SearchEmpty();
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: results.items.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: Colors.white12,
                  ),
                  itemBuilder: (context, index) {
                    final user = results.items[index];
                    final isPending = pending.contains(user.id);
                    return _SearchResultTile(
                      user: user,
                      isPending: isPending,
                      onFollowToggle: () => _toggleFollow(user),
                      theme: theme,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SocialUserSummary user;
  final bool isPending;
  final VoidCallback onFollowToggle;
  final ThemeData theme;

  const _SearchResultTile({
    required this.user,
    required this.isPending,
    required this.onFollowToggle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.resolvedAvatarUrl;
    final showFollow = !user.isSelf;

    String buttonLabel;
    if (user.isFriend) {
      buttonLabel = 'Friends';
    } else if (user.isFollowing) {
      buttonLabel = 'Following';
    } else if (user.isFollowedBy) {
      buttonLabel = 'Follow Back';
    } else {
      buttonLabel = 'Follow';
    }

    return ListTile(
      onTap: () {
        context.push('/profile/${user.username}');
      },
      leading: CircleAvatar(
        radius: 24,
        // was: theme.colorScheme.primary.withOpacity(0.2)
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
        child: avatarUrl == null
            ? const Icon(Icons.person, color: Colors.white70)
            : null,
      ),
      title: Text(
        user.primaryText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        user.secondaryText,
        style: const TextStyle(color: Colors.white54),
      ),
      trailing: showFollow
          ? SizedBox(
              width: 120,
              child: ElevatedButton(
                onPressed: isPending ? null : onFollowToggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: user.isFollowing
                      ? Colors.white10
                      : theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: isPending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        buttonLabel,
                        style: const TextStyle(fontSize: 12),
                      ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _SearchPlaceholder extends StatelessWidget {
  const _SearchPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'Search for athletes to follow. Use names, usernames, or partial matches.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 16),
        ),
      ),
    );
  }
}

class _SearchEmpty extends StatelessWidget {
  const _SearchEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No athletes found. Try a different name.',
        style: const TextStyle(color: Colors.white60),
      ),
    );
  }
}

class _SearchError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SearchError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
