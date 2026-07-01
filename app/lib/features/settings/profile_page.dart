import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../models/settings_models.dart';
import '../../services/api_client.dart';
import 'providers/settings_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kAmber = Color(0xFFFBBF24);
const _kRose = Color(0xFFF43F5E);
const _kGrey = Color(0xFF6B7280);
const _kBg = Color(0xFFF3F4F6);

// ─────────────────────────────────────────────────────────────────────────────
// ProfilePage
// ─────────────────────────────────────────────────────────────────────────────

class ProfilePage extends HookConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final googleAsync = ref.watch(googleLinkProvider);
    final hasPasswordAsync = ref.watch(hasPasswordProvider);

    final profile = profileAsync.value;
    final googleStatus = googleAsync.value;
    final hasPassword = hasPasswordAsync.value ?? true;

    // Image picking
    final imagePicking = useState(false);

    // Name editing
    final nameCtrl = useTextEditingController(text: profile?.name ?? '');
    final nameSaving = useState(false);
    final nameSaved = useState(false);

    // Password
    final currentPassCtrl = useTextEditingController();
    final newPassCtrl = useTextEditingController();
    final confirmPassCtrl = useTextEditingController();
    final showCurrentPass = useState(false);
    final showNewPass = useState(false);
    final showConfirmPass = useState(false);
    final passError = useState<String?>(null);
    final passUpdating = useState(false);
    final passUpdated = useState(false);

    // Sync name ctrl when profile loads
    useEffect(() {
      if (profile?.name != null && nameCtrl.text.isEmpty) {
        nameCtrl.text = profile!.name!;
      }
      return null;
    }, [profile?.name]);

    useListenable(newPassCtrl);
    useListenable(confirmPassCtrl);

    final passMatch =
        confirmPassCtrl.text.isEmpty || newPassCtrl.text == confirmPassCtrl.text;

    Future<void> pickImage() async {
      imagePicking.value = true;
      try {
        final picker = ImagePicker();
        final file = await picker.pickImage(source: ImageSource.gallery);
        if (file == null) return;

        final bytes = await file.readAsBytes();
        if (bytes.length > 10 * 1024 * 1024) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('圖片大小不能超過 10MB')),
            );
          }
          return;
        }

        final decoded = img.decodeImage(Uint8List.fromList(bytes));
        if (decoded == null) return;

        final size = math.min(decoded.width, decoded.height);
        final x = (decoded.width - size) ~/ 2;
        final y = (decoded.height - size) ~/ 2;
        final cropped = img.copyCrop(decoded, x: x, y: y, width: size, height: size);
        final resized = img.copyResize(cropped, width: 200, height: 200);
        final jpeg = img.encodeJpg(resized, quality: 85);
        final dataUrl = 'data:image/jpeg;base64,${base64Encode(jpeg)}';

        await ref.read(userProfileProvider.notifier).updateProfile(picture: dataUrl);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('上傳失敗: $e')));
        }
      } finally {
        imagePicking.value = false;
      }
    }

    Future<void> saveName() async {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) return;
      nameSaving.value = true;
      try {
        await ref.read(userProfileProvider.notifier).updateProfile(name: name);
        nameSaved.value = true;
        Future.delayed(const Duration(seconds: 2), () => nameSaved.value = false);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      } finally {
        nameSaving.value = false;
      }
    }

    Future<void> updatePassword() async {
      if (!passMatch || newPassCtrl.text.isEmpty || currentPassCtrl.text.isEmpty) {
        passError.value = '請確認所有欄位填寫正確';
        return;
      }
      passError.value = null;
      passUpdating.value = true;
      try {
        await ApiClient().updatePassword(
          currentPassword: currentPassCtrl.text,
          newPassword: newPassCtrl.text,
        );
        currentPassCtrl.clear();
        newPassCtrl.clear();
        confirmPassCtrl.clear();
        passUpdated.value = true;
        Future.delayed(
            const Duration(seconds: 2), () => passUpdated.value = false);
      } catch (e) {
        passError.value = '$e';
      } finally {
        passUpdating.value = false;
      }
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header bar ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Material(
                    shape: const CircleBorder(),
                    color: Colors.white,
                    elevation: 1,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.arrow_back_rounded, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '個人資料',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 頭像 ────────────────────────────────────────
                    _AvatarSection(
                      profile: profile,
                      picking: imagePicking.value,
                      onTap: pickImage,
                    ),
                    const SizedBox(height: 24),

                    // ── 基本資料 ─────────────────────────────────────
                    _SectionTitle('基本資料'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Material(
                        elevation: 1,
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                              child: Text(
                                '顯示名稱',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: nameCtrl,
                                    decoration: InputDecoration(
                                      hintText: '輸入顯示名稱',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 12),
                                    ),
                                    onSubmitted: (_) => saveName(),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed:
                                          nameSaving.value ? null : saveName,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _kAmber,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      child: nameSaving.value
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white),
                                            )
                                          : Text(
                                              nameSaved.value
                                                  ? '✓ 已儲存'
                                                  : '儲存名稱',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── 密碼 (has_password) ──────────────────────────
                    if (hasPassword) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Material(
                          elevation: 1,
                          borderRadius: BorderRadius.circular(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                                child: Text(
                                  '修改密碼',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15),
                                ),
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    _PassField(
                                      ctrl: currentPassCtrl,
                                      label: '目前密碼',
                                      show: showCurrentPass.value,
                                      onToggle: () => showCurrentPass.value =
                                          !showCurrentPass.value,
                                    ),
                                    const SizedBox(height: 12),
                                    _PassField(
                                      ctrl: newPassCtrl,
                                      label: '新密碼',
                                      show: showNewPass.value,
                                      onToggle: () => showNewPass.value =
                                          !showNewPass.value,
                                    ),
                                    const SizedBox(height: 12),
                                    _PassField(
                                      ctrl: confirmPassCtrl,
                                      label: '確認新密碼',
                                      show: showConfirmPass.value,
                                      onToggle: () => showConfirmPass.value =
                                          !showConfirmPass.value,
                                      hasError: !passMatch,
                                    ),
                                    if (!passMatch)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 6),
                                        child: Text(
                                          '兩次密碼不一致',
                                          style: TextStyle(
                                              color: _kRose, fontSize: 12),
                                        ),
                                      ),
                                    if (passError.value != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          passError.value!,
                                          style: const TextStyle(
                                              color: _kRose, fontSize: 12),
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: passUpdating.value
                                            ? null
                                            : updatePassword,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _kAmber,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          elevation: 0,
                                        ),
                                        child: passUpdating.value
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white),
                                              )
                                            : Text(
                                                passUpdated.value
                                                    ? '✓ 已更新'
                                                    : '更新密碼',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Google-only notice ───────────────────────────
                    if (googleStatus?.linked == true && !hasPassword)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Text(
                            '你使用 Google 帳號登入，帳號安全性由 Google 管理。',
                            style: TextStyle(
                                color: Color(0xFF1E40AF), fontSize: 13),
                          ),
                        ),
                      ),

                    // ── Google profile ───────────────────────────────
                    if (googleStatus?.linked == true &&
                        (googleStatus?.name != null ||
                            googleStatus?.picture != null)) ...[
                      const SizedBox(height: 16),
                      _SectionTitle('Google 帳號'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Material(
                          elevation: 1,
                          borderRadius: BorderRadius.circular(20),
                          child: Column(
                            children: [
                              ListTile(
                                leading: googleStatus?.picture != null
                                    ? CircleAvatar(
                                        backgroundImage: NetworkImage(
                                            googleStatus!.picture!),
                                        radius: 20,
                                      )
                                    : const CircleAvatar(
                                        backgroundColor: Color(0xFF4285F4),
                                        radius: 20,
                                        child: Text('G',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                title: Text(googleStatus?.name ?? ''),
                                subtitle: const Text('Google 帳號'),
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      await ref
                                          .read(userProfileProvider.notifier)
                                          .updateProfile(
                                            name: googleStatus!.name,
                                            picture: googleStatus.picture,
                                          );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          content: Text('已套用 Google 帳號資料'),
                                        ));
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                        minimumSize:
                                            const Size(double.infinity, 44)),
                                    child: const Text('套用 Google 帳號的名稱和大頭照'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar Section
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.profile,
    required this.picking,
    required this.onTap,
  });
  final UserProfile? profile;
  final bool picking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pic = profile?.picture;
    final letter =
        ((profile?.name?.isNotEmpty == true) ? profile!.name![0] : '?')
            .toUpperCase();

    Widget avatar;
    if (picking) {
      avatar = const CircularProgressIndicator(color: _kAmber);
    } else if (pic != null && pic.startsWith('data:')) {
      avatar = ClipOval(
        child: Image.memory(base64Decode(pic.split(',').last),
            fit: BoxFit.cover, width: 96, height: 96),
      );
    } else if (pic != null) {
      avatar = ClipOval(
        child: Image.network(pic,
            fit: BoxFit.cover, width: 96, height: 96,
            errorBuilder: (_, __, ___) => _letterAvatar(letter)),
      );
    } else {
      avatar = _letterAvatar(letter);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          GestureDetector(
            onTap: picking ? null : onTap,
            child: Stack(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8)
                    ],
                  ),
                  child: ClipOval(child: Center(child: avatar)),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: picking
                        ? const Padding(
                            padding: EdgeInsets.all(6),
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt_rounded,
                            size: 18, color: _kGrey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile?.name ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          if (profile?.email != null)
            Text(profile!.email!,
                style: const TextStyle(color: _kGrey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _letterAvatar(String letter) => Container(
        color: _kAmber,
        alignment: Alignment.center,
        child: Text(letter,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Title
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 12, color: _kGrey, fontWeight: FontWeight.w500)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Password Field
// ─────────────────────────────────────────────────────────────────────────────

class _PassField extends StatelessWidget {
  const _PassField({
    required this.ctrl,
    required this.label,
    required this.show,
    required this.onToggle,
    this.hasError = false,
  });
  final TextEditingController ctrl;
  final String label;
  final bool show;
  final VoidCallback onToggle;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      obscureText: !show,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: hasError
              ? const BorderSide(color: _kRose, width: 1.5)
              : const BorderSide(),
        ),
        enabledBorder: hasError
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kRose, width: 1.5),
              )
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        suffixIcon: IconButton(
          icon: Icon(show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
