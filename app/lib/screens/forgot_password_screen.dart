import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';

const _kOrange = Color(0xFFF5A623);

class ForgotPasswordScreen extends HookWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final emailCtrl = useTextEditingController();
    final codeCtrl = useTextEditingController();
    final newPasswordCtrl = useTextEditingController();
    final confirmPasswordCtrl = useTextEditingController();

    final codeSent = useState(false);
    final sending = useState(false);
    final resetting = useState(false);
    final errorMsg = useState<String?>(null);
    final infoMsg = useState<String?>(null);

    Future<void> sendCode() async {
      final email = emailCtrl.text.trim();
      if (email.isEmpty) {
        errorMsg.value = '請輸入 email';
        return;
      }
      sending.value = true;
      errorMsg.value = null;
      infoMsg.value = null;
      try {
        await AuthService().forgotPassword(email: email);
        codeSent.value = true;
        infoMsg.value = '驗證碼已寄出，請檢查你的信箱（10 分鐘內有效）';
      } catch (e) {
        errorMsg.value = e.toString().replaceFirst('Exception: ', '');
      } finally {
        sending.value = false;
      }
    }

    Future<void> resetPassword() async {
      final email = emailCtrl.text.trim();
      final code = codeCtrl.text.trim();
      final newPassword = newPasswordCtrl.text;
      if (code.isEmpty || newPassword.isEmpty) {
        errorMsg.value = '請填寫驗證碼和新密碼';
        return;
      }
      if (newPassword != confirmPasswordCtrl.text) {
        errorMsg.value = '兩次輸入的密碼不一致';
        return;
      }
      resetting.value = true;
      errorMsg.value = null;
      try {
        await AuthService().resetPassword(email: email, code: code, newPassword: newPassword);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('密碼已重設，請重新登入')));
          context.pop();
        }
      } catch (e) {
        errorMsg.value = e.toString().replaceFirst('Exception: ', '');
      } finally {
        resetting.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('忘記密碼')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('輸入註冊時使用的 email，我們會寄一組 6 位數驗證碼給你。'),
              const SizedBox(height: 20),
              TextField(
                controller: emailCtrl,
                enabled: !codeSent.value,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (!codeSent.value)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: sending.value ? null : sendCode,
                    style: FilledButton.styleFrom(backgroundColor: _kOrange),
                    child: sending.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('寄送驗證碼'),
                  ),
                ),
              if (codeSent.value) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '6 位數驗證碼',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '新密碼',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '確認新密碼',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: resetting.value ? null : resetPassword,
                    style: FilledButton.styleFrom(backgroundColor: _kOrange),
                    child: resetting.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('重設密碼'),
                  ),
                ),
                TextButton(
                  onPressed: sending.value ? null : sendCode,
                  child: const Text('沒收到？重新寄送驗證碼'),
                ),
              ],
              if (infoMsg.value != null) ...[
                const SizedBox(height: 12),
                Text(infoMsg.value!, style: const TextStyle(color: Colors.green)),
              ],
              if (errorMsg.value != null) ...[
                const SizedBox(height: 12),
                Text(errorMsg.value!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
