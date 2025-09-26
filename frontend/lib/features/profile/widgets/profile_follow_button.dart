// frontend/lib/features/profile/widgets/profile_follow_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/social_user.dart';
import '../../../core/providers/api_providers.dart';
import '../providers/user_relationship_provider.dart';

class ProfileFollowButton extends ConsumerStatefulWidget {
  final String userId;

  const ProfileFollowButton({super.key, required this.userId});

  @override
  ConsumerState<ProfileFollowButton> createState() => _ProfileFollowButtonState();
}

class _ProfileFollowButtonState extends ConsumerState<ProfileFollowButton> {
  bool _isProcessing = false;

  Future<void> _toggleFollow(SocialUserSummary summary) async {
    if (_isProcessing || summary.isSelf) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final client = ref.read(privateHttpClientProvider);
      if (summary.isFollowing) {
        await client.delete('/users/${widget.userId}/follow');
      } else {
        await client.post('/users/${widget.userId}/follow');
      }
      ref.invalidate(userRelationshipProvider(widget.userId));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to update follow status: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      } else {
        _isProcessing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final relationshipAsync = ref.watch(userRelationshipProvider(widget.userId));

    return relationshipAsync.when(
      data: (summary) {
        if (summary.isSelf) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final bool isFriend = summary.isFriend;
        final bool isFollowing = summary.isFollowing;

        String label;
        if (isFriend) {
          label = 'Friends';
        } else if (isFollowing) {
          label = 'Following';
        } else {
          label = 'Follow';
        }

        final Widget child = _isProcessing
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              );

        if (!isFollowing && !isFriend) {
          return SizedBox(
            height: 36,
            child: FilledButton(
              onPressed: _isProcessing ? null : () => _toggleFollow(summary),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                minimumSize: const Size(120, 36),
              ),
              child: child,
            ),
          );
        }

        final outlineColor =
            isFriend ? theme.colorScheme.primary : Colors.white38;
        final background = isFriend
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.04);

        return SizedBox(
          height: 36,
          child: OutlinedButton(
            onPressed: _isProcessing ? null : () => _toggleFollow(summary),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: outlineColor, width: 1.5),
              backgroundColor: background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              minimumSize: const Size(120, 36),
            ),
            child: child,
          ),
        );
      },
      loading: () => const SizedBox(
        height: 36,
        width: 120,
        child: Center(
          child: SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, _) => SizedBox(
        height: 36,
        child: OutlinedButton(
          onPressed: () =>
              ref.invalidate(userRelationshipProvider(widget.userId)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('Retry', style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
