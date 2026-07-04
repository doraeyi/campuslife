import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../services/api_client.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final ApiClient _apiClient = ApiClient();
  late Future<List<Friendship>> _friendshipsFuture;
  final _emailController = TextEditingController();
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _friendshipsFuture = _apiClient.fetchFriendships();
    });
  }

  Future<void> _sendRequest() async {
    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      await _apiClient.requestFriend(_emailController.text);
      _emailController.clear();
      _refresh();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _accept(int friendshipId) async {
    await _apiClient.acceptFriend(friendshipId);
    _refresh();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('好友')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: '輸入對方 email 加好友',
                      prefixIcon: Icon(Icons.person_add_alt),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSending ? null : _sendRequest,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: FutureBuilder<List<Friendship>>(
              future: _friendshipsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final friendships = snapshot.data ?? [];
                if (friendships.isEmpty) {
                  return const Center(child: Text('還沒有好友,輸入 email 邀請看看'));
                }
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView(
                    children: friendships.map((f) {
                      if (f.status == 'accepted') {
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(f.friend.displayName),
                          subtitle: Text(f.friend.email),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push(
                            '/friends/${f.friend.id}/schedule',
                            extra: f.friend.displayName,
                          ),
                        );
                      }
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                        title: Text(f.friend.displayName),
                        subtitle: Text(f.incoming ? '想加你好友' : '等待對方接受'),
                        trailing: f.incoming
                            ? FilledButton(
                                onPressed: () => _accept(f.id),
                                child: const Text('接受'),
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
