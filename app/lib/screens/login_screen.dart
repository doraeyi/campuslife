import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/auth_provider.dart';

const _kOrange = Color(0xFFF5A623);
const _kSubtitleBlue = Color(0xFF6C63FF);

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailCtrl    = useTextEditingController();
    final passwordCtrl = useTextEditingController();
    final isLoading    = useState(false);
    final isGoogleLoading = useState(false);
    final errorMsg     = useState<String?>(null);

    Future<void> submit() async {
      final email    = emailCtrl.text.trim();
      final password = passwordCtrl.text;
      if (email.isEmpty || password.isEmpty) {
        errorMsg.value = '請填寫帳號和密碼';
        return;
      }

      isLoading.value = true;
      errorMsg.value  = null;

      // AuthNotifier.login() 用 AsyncValue.guard 包錯誤，不會往外丟例外，
      // 所以登入失敗與否要看 provider 的 state，不能靠 try/catch。
      await ref.read(authProvider.notifier).login(
        email: email,
        password: password,
      );
      final state = ref.read(authProvider);
      if (state.hasError) {
        errorMsg.value = state.error.toString().replaceFirst('Exception: ', '');
      } else if (context.mounted) {
        context.go('/dashboard');
      }
      isLoading.value = false;
    }

    Future<void> submitWithGoogle() async {
      isGoogleLoading.value = true;
      errorMsg.value = null;

      try {
        await ref.read(authProvider.notifier).loginWithGoogle();
        if (context.mounted) context.go('/dashboard');
      } catch (e) {
        errorMsg.value = e.toString().replaceFirst('Exception: ', '');
      } finally {
        isGoogleLoading.value = false;
      }
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF232329) : Colors.white;
    final dividerColor = isDark ? Colors.white24 : Colors.grey.shade300;
    final mutedText = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/logo.png', width: 220, fit: BoxFit.contain),
                const SizedBox(height: 12),
                const Text(
                  '登入你的帳號',
                  style: TextStyle(color: _kSubtitleBlue, fontSize: 14),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('帳號', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _LoginTextField(
                        controller: emailCtrl,
                        hintText: '輸入帳號',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 20),
                      const Text('密碼', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _LoginTextField(
                        controller: passwordCtrl,
                        hintText: '輸入密碼',
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => submit(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/forgot-password'),
                          style: TextButton.styleFrom(
                            foregroundColor: _kOrange,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('忘記密碼？', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                      if (errorMsg.value != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMsg.value!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: isLoading.value ? null : submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: _kOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
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
                              : const Text('登入', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
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
                  width: double.infinity,
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _GoogleG(),
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
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('還沒有帳號？', style: TextStyle(color: mutedText)),
                    TextButton(
                      // push 而非 go，讓返回鍵可以回到登入頁
                      onPressed: () => context.push('/register'),
                      style: TextButton.styleFrom(foregroundColor: _kOrange),
                      child: const Text('註冊', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: isDark ? const Color(0xFF34343C) : const Color(0xFFF1F2F5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}
