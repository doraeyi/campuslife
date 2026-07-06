import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';

/// Horizontal strip of accepted friends' avatars — tap one to view their
/// schedule, or tap the trailing "+" to add/manage friends.
class FriendsBanner extends StatelessWidget {
  const FriendsBanner({super.key, required this.friendships});
  final List<Friendship> friendships;

  @override
  Widget build(BuildContext context) {
    final accepted = friendships.where((f) => f.status == 'accepted').toList();
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '好友',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.outline,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 84,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ...accepted.map((f) => _FriendAvatar(
                        friend: f.friend,
                        onTap: () => context.push(
                          '/friends/${f.friend.id}/schedule',
                          extra: f.friend.displayName,
                        ),
                      )),
                  _AddFriendTile(onTap: () => context.push('/friends')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.friend, required this.onTap});
  final AppUser friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final letter = friend.displayName.isNotEmpty ? friend.displayName[0].toUpperCase() : '?';
    final pic = friend.picture;

    Widget avatarChild;
    if (pic != null && pic.isNotEmpty) {
      avatarChild = CircleAvatar(radius: 28, backgroundImage: NetworkImage(pic));
    } else {
      avatarChild = CircleAvatar(
        radius: 28,
        backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
        child: Text(letter,
            style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 18)),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              avatarChild,
              const SizedBox(height: 6),
              Text(
                friend.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddFriendTile extends StatelessWidget {
  const _AddFriendTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              child: Icon(Icons.person_add_alt_rounded,
                  color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 6),
            Text('加好友',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
