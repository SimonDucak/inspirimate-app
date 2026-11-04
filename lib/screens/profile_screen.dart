import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'progress_screen.dart';
import 'questionnaire_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _imagePicker = ImagePicker();
  String? _avatarPath;
  String? _avatarUrl;
  bool _loading = true;
  bool _saving = false;

  SupabaseClient get _client => Supabase.instance.client;
  String get _userId => _client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _client
          .from('profiles')
          .select('first_name, last_name, avatar_path')
          .eq('user_id', _userId)
          .maybeSingle();
      if (profile != null) {
        _firstNameController.text = profile['first_name'] as String? ?? '';
        _lastNameController.text = profile['last_name'] as String? ?? '';
        _avatarPath = profile['avatar_path'] as String?;
        await _refreshAvatarUrl();
      }
    } catch (_) {
      if (mounted) _showMessage('Profil sa nepodarilo načítať.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshAvatarUrl() async {
    final path = _avatarPath;
    if (path == null) return;
    try {
      _avatarUrl = await _client.storage
          .from('profile-photos')
          .createSignedUrl(path, 3600);
    } catch (_) {
      _avatarUrl = null;
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _showMessage('Fotografia môže mať najviac 5 MB.');
        return;
      }
      final extension = image.name.split('.').last.toLowerCase();
      final contentType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      };
      if (contentType == null) {
        _showMessage('Použite fotografiu vo formáte JPG, PNG alebo WebP.');
        return;
      }

      setState(() => _saving = true);
      final path = '$_userId/avatar.$extension';
      await _client.storage
          .from('profile-photos')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      await _client.from('profiles').upsert({
        'user_id': _userId,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'avatar_path': path,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      _avatarPath = path;
      await _refreshAvatarUrl();
      if (mounted) setState(() {});
      _showMessage('Profilová fotografia bola uložená.');
    } catch (_) {
      _showMessage('Fotografiu sa nepodarilo nahrať. Skúste to znova.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await _client.from('profiles').upsert({
        'user_id': _userId,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'avatar_path': _avatarPath,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) _showMessage('Profil bol uložený.');
    } catch (_) {
      if (mounted) {
        _showMessage('Profil sa nepodarilo uložiť. Skúste to znova.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Môj profil')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 58,
                        backgroundColor: const Color(0xFF202820),
                        foregroundImage: _avatarUrl == null
                            ? null
                            : NetworkImage(_avatarUrl!),
                        child: _avatarUrl == null
                            ? const Icon(
                                Icons.person_rounded,
                                size: 58,
                                color: Color(0xFFB8F36B),
                              )
                            : null,
                      ),
                      IconButton.filled(
                        tooltip: 'Zmeniť profilovú fotografiu',
                        onPressed: _saving ? null : _pickAvatar,
                        icon: const Icon(Icons.camera_alt_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _firstNameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Meno',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: _requiredName,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _lastNameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Priezvisko',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: _requiredName,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _saveProfile,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: const Text('Uložiť profil'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => const ProgressScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.insights_rounded),
                          label: const Text('Môj pokrok'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => const QuestionnaireScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.assignment_outlined),
                          label: const Text('Vyplniť vstupný dotazník'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
  );

  String? _requiredName(String? value) =>
      (value?.trim().isNotEmpty ?? false) ? null : 'Toto pole je povinné.';
}
