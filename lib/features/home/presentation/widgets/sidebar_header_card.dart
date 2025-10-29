import 'package:flutter/material.dart';

/// Header user card for the sidebar showing user information
class SidebarHeaderCard extends StatelessWidget {
  const SidebarHeaderCard({
    super.key,
    required this.userName,
    required this.userId,
    required this.userAvatar,
    required this.onCollapse,
  });

  final String userName;
  final String? userId;
  final String? userAvatar;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: (userAvatar != null && userAvatar!.isNotEmpty)
                ? NetworkImage(userAvatar!)
                : null,
            backgroundColor: scheme.primaryContainer,
            child: (userAvatar == null || userAvatar!.isEmpty)
                ? Icon(
                    Icons.person,
                    size: 20,
                    color: scheme.onPrimaryContainer,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (userId != null)
                  Text(
                    'ID: $userId',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
