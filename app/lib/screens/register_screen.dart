import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/auth_provider.dart';

class RegisterScreen extends HookConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameCtrl     = useTextEditingController();
    final emailCtrl    = useTextEditingController();
    final passwordCtrl = useTextEditingController();
    final isLoading    = useState(false);
    final isGoogleLoading = useState(false);
    final errorMsg     = useState<String?>(null);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF232329) : Colors.white;
    final dividerColor = isDark ? Colors.white24 : Colors.grey.shade300;
    final mutedText = isDark ? Colors.grey.shade400 : Colors.grey.shade500;

    Future<void> submit() async {
      final name     = nameCtrl.text.trim();
      final email    = emailCtrl.text.trim();
      final password = passwordCtrl.text;
      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        errorMsg.value = '請填寫所有欄位';
        return;
      }

      isLoading.value = true;
      errorMsg.value  = null;

      try {
        await ref.read(authProvider.notifier).register(
          email: email,
          password: password,
          displayName: name,
        );
        if (context.mounted) context.go('/dashboard');
      } catch (e) {
        errorMsg.value = e.toString().replaceFirst('Exception: ', '');
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> submitWithGoogle() async {
      isGoogleLoading.value = true;
      errorMsg.value = null;

      try {
        // Google 登入沒有帳號時會自動建立，註冊/登入共用同一支後端邏輯
        await ref.read(authProvider.notifier).loginWithGoogle();
        if (context.mounted) context.go('/dashboard');
      } catch (e) {
        errorMsg.value = e.toString().replaceFirst('Exception: ', '');
      } finally {
        isGoogleLoading.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('註冊帳號')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '顯示名稱',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
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
                    : const Text('註冊'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: dividerColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('或', style: TextStyle(color: mutedText)),
                  ),
                  Expanded(child: Divider(color: dividerColor)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: isGoogleLoading.value ? null : submitWithGoogle,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: cardColor,
                    side: BorderSide(color: dividerColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isGoogleLoading.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'G',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4285F4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '使用 Google 帳號登入',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
