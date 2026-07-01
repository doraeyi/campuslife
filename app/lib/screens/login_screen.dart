import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/auth_provider.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailCtrl    = useTextEditingController();
    final passwordCtrl = useTextEditingController();
    final isLoading    = useState(false);
    final errorMsg     = useState<String?>(null);

    Future<void> submit() async {
      final email    = emailCtrl.text.trim();
      final password = passwordCtrl.text;
      if (email.isEmpty || password.isEmpty) {
        errorMsg.value = '請填寫 Email 和密碼';
        return;
      }

      isLoading.value = true;
      errorMsg.value  = null;

      try {
        await ref.read(authProvider.notifier).login(
          email: email,
          password: password,
        );
        if (context.mounted) context.go('/dashboard');
      } catch (e) {
        errorMsg.value = e.toString().replaceFirst('Exception: ', '');
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'CampusLife',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submit(),
                  decoration: const InputDecoration(
                    labelText: '密碼',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (errorMsg.value != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMsg.value!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isLoading.value ? null : submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: isLoading.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('登入'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  // push 而非 go，讓返回鍵可以回到登入頁
                  onPressed: () => context.push('/register'),
                  child: const Text('還沒有帳號？註冊'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
