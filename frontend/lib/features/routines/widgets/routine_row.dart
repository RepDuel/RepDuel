// frontend/lib/features/routines/widgets/routine_row.dart

import 'package:flutter/material.dart';

class RoutineRow extends StatelessWidget {
  const RoutineRow({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.durationMinutes,
    required this.badges,
    required this.onTap,
    required this.menuBuilder,
    required this.onMenuSelected,
  });

  final String title;
  final String? imageUrl;
  final int durationMinutes;
  final List<String> badges;
  final VoidCallback onTap;
  final PopupMenuItemBuilder<String> menuBuilder;
  final PopupMenuItemSelected<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodySmall = theme.textTheme.bodySmall;
    final bodySmallColor = bodySmall?.color;
    final secondaryColor = bodySmallColor?.withValues(alpha: 0.8) ??
        theme.colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Thumb(imageUrl: imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Title(text: title),
                    const SizedBox(height: 6),
                    DefaultTextStyle(
                      style: bodySmall?.copyWith(color: secondaryColor) ??
                          TextStyle(
                            color: secondaryColor,
                            fontSize: theme.textTheme.bodySmall?.fontSize,
                          ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.timer_outlined, size: 14),
                          const SizedBox(width: 4),
                          Text('$durationMinutes min'),
                          const SizedBox(width: 10),
                          Expanded(
                            child: badges.isEmpty
                                ? const SizedBox.shrink()
                                : _Badges(badges: badges),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'More',
                onSelected: onMenuSelected,
                itemBuilder: menuBuilder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const placeholder = 'assets/images/routine_placeholder.png';

    Widget child;
    if (imageUrl != null &&
        (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'))) {
      child = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        cacheWidth: 160,
        errorBuilder: (_, __, ___) => Image.asset(
          placeholder,
          fit: BoxFit.cover,
        ),
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      child = Image.asset(
        imageUrl!,
        fit: BoxFit.cover,
      );
    } else {
      child = Image.asset(
        placeholder,
        fit: BoxFit.cover,
      );
    }

    final theme = Theme.of(context);

    return SizedBox(
      width: 68,
      height: 68,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.24),
          ),
          child: SizedBox.expand(
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      softWrap: true,
      textHeightBehavior:
          const TextHeightBehavior(applyHeightToFirstAscent: false),
      style: style,
    );
  }
}

class _Badges extends StatelessWidget {
  const _Badges({required this.badges});

  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = theme.colorScheme.primary.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.18 : 0.12,
    );

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: badges.take(6).map((badge) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: badgeColor,
          ),
          child: Text(
            badge,
            style: theme.textTheme.labelSmall,
          ),
        );
      }).toList(),
    );
  }
}
