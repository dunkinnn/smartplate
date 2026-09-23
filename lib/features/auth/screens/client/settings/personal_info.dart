import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/services/friendly_error.dart';
import 'package:smart_plate/features/auth/widgets/settings_form.dart';

// Edits the name, photo and body measurements on user_profiles.
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  static const genderOptions = ['Male', 'Female', 'Other'];

  final _fullName = TextEditingController();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();

  String? _gender;
  String? _avatarUrl;
  File? _newAvatar;
  String _email = '';

  bool _isLoading = true;
  bool _isSaving = false;
  String? _message;
  bool _messageIsError = true;

  @override
  void initState() {
    super.initState();
    _email = Supabase.instance.client.auth.currentUser?.email ?? '';
    _load();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  String _text(dynamic value) => value == null ? '' : '$value';

  Future<void> _load() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final row = await supabase
          .from('user_profiles')
          .select('full_name, avatar_url, age, gender, height_cm, weight_kg')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() {
        _fullName.text = _text(row?['full_name']);
        _age.text = _text(row?['age']);
        _height.text = _text(row?['height_cm']);
        _weight.text = _text(row?['weight_kg']);
        _gender = row?['gender'] as String?;
        _avatarUrl = row?['avatar_url'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = 'Could not load your details.';
      });
    }
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: SettingsScaffold.brandGreen,
              ),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_camera,
                color: SettingsScaffold.brandGreen,
              ),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked != null && mounted) {
      setState(() => _newAvatar = File(picked.path));
    }
  }

  Future<String?> _uploadAvatar(String userId) async {
    final file = _newAvatar;
    if (file == null) return _avatarUrl;

    const bucket = 'avatars';
    final path = '$userId/avatar.jpg';
    final storage = Supabase.instance.client.storage.from(bucket);

    await storage.upload(
      path,
      file,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );

    final stamp = DateTime.now().millisecondsSinceEpoch;
    return '${storage.getPublicUrl(path)}?v=$stamp';
  }

  Future<void> _save() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final name = _fullName.text.trim();
    if (name.isEmpty) {
      setState(() {
        _message = 'Full name is required.';
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      final avatarUrl = await _uploadAvatar(user.id);

      await Supabase.instance.client
          .from('user_profiles')
          .update({
            'full_name': name,
            'avatar_url': avatarUrl,
            'age': int.tryParse(_age.text.trim()),
            'gender': _gender,
            'height_cm': double.tryParse(_height.text.trim()),
            'weight_kg': double.tryParse(_weight.text.trim()),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _newAvatar = null;
        _avatarUrl = avatarUrl;
        _message = 'Details saved.';
        _messageIsError = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _message = friendlyError(e);
        _messageIsError = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _message = 'Could not save your photo. Please try again.';
        _messageIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: SettingsScaffold.brandGreen),
        ),
      );
    }

    return SettingsScaffold(
      title: "Personal Info",
      subtitle: "Your name, photo and measurements",
      isSaving: _isSaving,
      message: _message,
      messageIsError: _messageIsError,
      onDismissMessage: () => setState(() => _message = null),
      onSave: _save,
      children: [
        Center(child: _buildAvatarPicker()),
        const SizedBox(height: 30),

        const SettingsLabel('FULL NAME'),
        SettingsTextField(controller: _fullName, hint: 'Enter your full name'),
        const SizedBox(height: 20),

        const SettingsLabel('EMAIL'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            _email,
            style: const TextStyle(
              color: SettingsScaffold.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Email is tied to your login and cannot be changed here.",
          style: TextStyle(fontSize: 11, color: SettingsScaffold.textSecondary),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SettingsLabel('AGE'),
                  SettingsTextField(
                    controller: _age,
                    hint: 'e.g. 25',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SettingsLabel('GENDER'),
                  SettingsDropdown(
                    hint: 'Select',
                    value: _gender,
                    items: genderOptions,
                    onChanged: (v) => setState(() => _gender = v),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SettingsLabel('HEIGHT'),
                  SettingsTextField(
                    controller: _height,
                    hint: 'e.g. 170',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    suffix: 'cm',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SettingsLabel('WEIGHT'),
                  SettingsTextField(
                    controller: _weight,
                    hint: 'e.g. 65',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    suffix: 'kg',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarPicker() {
    ImageProvider? image;
    if (_newAvatar != null) {
      image = FileImage(_newAvatar!);
    } else if (_avatarUrl != null) {
      image = NetworkImage(_avatarUrl!);
    }

    return GestureDetector(
      onTap: _pickAvatar,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 55,
            backgroundColor: const Color(0xFFF8FAFC),
            backgroundImage: image,
            child: image == null
                ? const Icon(
                    Icons.person,
                    size: 50,
                    color: SettingsScaffold.textSecondary,
                  )
                : null,
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: SettingsScaffold.brandGreen,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
