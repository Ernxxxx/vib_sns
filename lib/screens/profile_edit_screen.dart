import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';

import '../data/preset_hashtags.dart';
import '../models/profile.dart';
import '../services/profile_interaction_service.dart';
import '../state/encounter_manager.dart';
import '../state/local_profile_loader.dart';
import '../state/profile_controller.dart';
import '../utils/auth_helpers.dart';
import '../utils/color_extensions.dart';
import '../utils/profile_setup_helper.dart';
import '../widgets/hashtag_picker.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _homeTownController;
  bool _saving = false;
  String? _avatarImageBase64;
  Uint8List? _avatarImageBytes;
  bool _avatarRemoved = false;
  final ImagePicker _picker = ImagePicker();
  VoidCallback? _nameListener;
  late final Set<String> _selectedHashtags;
  late final List<String> _availableHashtags;
  static const int _minHashtagSelection = 2;
  static const int _maxHashtagSelection = 10;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _usernameController =
        TextEditingController(text: widget.profile.username ?? '');
    _bioController =
        TextEditingController(text: _initialValue(widget.profile.bio));
    _homeTownController =
        TextEditingController(text: _initialValue(widget.profile.homeTown));
    _avatarImageBase64 = widget.profile.avatarImageBase64;
    _avatarImageBytes = _decodeAvatar(widget.profile.avatarImageBase64);
    _nameListener = () => setState(() {});
    _nameController.addListener(_nameListener!);
    _selectedHashtags = {...widget.profile.favoriteGames};
    final extras = widget.profile.favoriteGames
        .where((tag) => !presetHashtags.contains(tag));
    _availableHashtags = [...presetHashtags, ...extras];
  }

  @override
  void dispose() {
    if (_nameListener != null) {
      _nameController.removeListener(_nameListener!);
      _nameListener = null;
    }
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _homeTownController.dispose();
    super.dispose();
  }

  Uint8List? _decodeAvatar(String? base64) {
    if (base64 == null || base64.trim().isEmpty) {
      return null;
    }
    try {
      final bytes = base64Decode(base64.trim());
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  String _initialValue(String value) {
    if (value.trim().isEmpty) return '';
    if (value.trim() == '\u672a\u767b\u9332') return '';
    return value;
  }

  Future<void> _pickAvatar() async {
    try {
      // 画像を選択
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (file == null) {
        return;
      }

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      // 画像を正方形にパディングして全体が見えるようにする
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        _showSnack('画像の読み込みに失敗しました。');
        return;
      }
      final maxSide = originalImage.width > originalImage.height
          ? originalImage.width
          : originalImage.height;
      final squareImage = img.Image(width: maxSide, height: maxSide);
      // 背景を黒で塗りつぶし
      img.fill(squareImage, color: img.ColorRgba8(0, 0, 0, 255));
      // 中央に元画像を配置
      final offsetX = (maxSide - originalImage.width) ~/ 2;
      final offsetY = (maxSide - originalImage.height) ~/ 2;
      img.compositeImage(squareImage, originalImage,
          dstX: offsetX, dstY: offsetY);
      final paddedBytes = Uint8List.fromList(img.encodePng(squareImage));

      // カスタムクロップ画面へ遷移
      final Uint8List? croppedBytes = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _CropScreen(image: paddedBytes),
        ),
      );

      if (croppedBytes == null) {
        return;
      }

      setState(() {
        _avatarImageBytes = croppedBytes;
        _avatarImageBase64 = base64Encode(croppedBytes);
        _avatarRemoved = false;
      });
    } catch (e) {
      debugPrint('画像の読み込みに失敗: $e');
      _showSnack('画像の読み込みに失敗しました。');
    }
  }

  void _removeAvatar() {
    setState(() {
      _avatarImageBytes = null;
      _avatarImageBase64 = null;
      _avatarRemoved = true;
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedHashtags.length < _minHashtagSelection) {
      _showSnack('ハッシュタグを$_minHashtagSelection件以上選択してください。');
      return;
    }

    setState(() => _saving = true);
    final displayName = _nameController.text.trim();
    final username = Profile.normalizeUsername(_usernameController.text);
    final bio = _bioController.text.trim();
    final homeTown = _homeTownController.text.trim();
    final hashtags = _selectedHashtags.toList();

    final profileController = context.read<ProfileController>();
    final encounterManager = context.read<EncounterManager>();
    final interactionService = context.read<ProfileInteractionService>();
    final wasRunning = encounterManager.isRunning;

    try {
      if (username != null && username.isNotEmpty) {
        try {
          final ensuredUser = await ensureAnonymousAuth();
          final currentUser = ensuredUser ?? FirebaseAuth.instance.currentUser;
          if (currentUser == null) {
            _showSnack('認証情報を取得できませんでした。もう一度お試しください。');
            setState(() => _saving = false);
            return;
          }
          await syncUsernameReservation(
            profileId: widget.profile.id,
            authUid: currentUser.uid,
            currentUsername: widget.profile.username,
            nextUsername: username,
          );
        } on UsernameAlreadyTakenException {
          _showSnack('ユーザーID「@$username」は既に使用されています。');
          setState(() => _saving = false);
          return;
        }
      }

      final updated = await LocalProfileLoader.updateLocalProfile(
        displayName: displayName,
        username: username,
        bio: bio,
        homeTown: homeTown,
        favoriteGames: hashtags,
        avatarImageBase64: _avatarRemoved ? null : _avatarImageBase64,
        removeAvatarImage: _avatarRemoved,
      );
      await interactionService.bootstrapProfile(updated);
      profileController.updateProfile(updated, needsSetup: false);
      await encounterManager.switchLocalProfile(updated);
      if (wasRunning) {
        try {
          await encounterManager.start();
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      '\u3059\u308c\u9055\u3044\u3092\u518d\u8d77\u52d5\u3067\u304d\u307e\u305b\u3093\u3067\u3057\u305f: $error')),
            );
          }
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '\u30d7\u30ed\u30d5\u30a3\u30fc\u30eb\u306e\u4fdd\u5b58\u306b\u5931\u6557\u3057\u307e\u3057\u305f: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            '\u30d7\u30ed\u30d5\u30a3\u30fc\u30eb\u3092\u7de8\u96c6'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _handleSave,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('\u4fdd\u5b58'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + viewInsets),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final currentName = _nameController.text.trim();
                    final displayNameForAvatar = currentName.isNotEmpty
                        ? currentName
                        : widget.profile.displayName;
                    final hasInitialAvatar =
                        widget.profile.avatarImageBase64?.trim().isNotEmpty ??
                            false;
                    final hasAvatar = !_avatarRemoved &&
                        (_avatarImageBytes != null || hasInitialAvatar);
                    return _AvatarEditor(
                      imageBytes: _avatarImageBytes,
                      fallbackColor: Colors.grey,
                      displayName: displayNameForAvatar,
                      onPickImage: _pickAvatar,
                      onRemoveImage: hasAvatar ? _removeAvatar : null,
                      isSaving: _saving,
                    );
                  },
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: '\u8868\u793a\u540d',
                    hintText: '\u4f8b: \u3072\u306a\u305f',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return '\u540d\u524d\u3092\u5165\u529b\u3057\u3066\u304f\u3060\u3055\u3044';
                    }
                    if (trimmed.length > 24) {
                      return '24\u6587\u5b57\u4ee5\u5185\u3067\u5165\u529b\u3057\u3066\u304f\u3060\u3055\u3044';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'ユーザーID',
                    hintText: '@username',
                    prefixText: '@',
                    helperText: '英数字とアンダースコア、3〜20文字',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (value) {
                    return Profile.validateUsername(value);
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _bioController,
                  decoration: InputDecoration(
                    labelText: '\u4e00\u8a00\u30b3\u30e1\u30f3\u30c8',
                    hintText:
                        '\u3042\u306a\u305f\u306e\u30b9\u30c6\u30fc\u30bf\u30b9\u3084\u30b7\u30f3\u30d7\u30eb\u306a\u81ea\u5df1\u7d39\u4ecb',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.length > 120) {
                      return '120\u6587\u5b57\u4ee5\u5185\u306b\u3057\u3066\u304f\u3060\u3055\u3044';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _homeTownController,
                  decoration: InputDecoration(
                    labelText: '\u6d3b\u52d5\u30a8\u30ea\u30a2',
                    hintText:
                        '\u4f8b: \u6771\u4eac\u30a8\u30ea\u30a2 / \u95a2\u897f',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.length > 24) {
                      return '24\u6587\u5b57\u4ee5\u5185\u306b\u3057\u3066\u304f\u3060\u3055\u3044';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                HashtagPicker(
                  selectedTags: _selectedHashtags,
                  onChanged: (newTags) {
                    setState(() {
                      _selectedHashtags.clear();
                      _selectedHashtags.addAll(newTags);
                    });
                  },
                  minSelection: _minHashtagSelection,
                  maxSelection: _maxHashtagSelection,
                  availableTags: _availableHashtags,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _handleSave,
                    icon: const Icon(Icons.save_outlined),
                    label: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('\u4fdd\u5b58\u3057\u3066\u623b\u308b'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarEditor extends StatelessWidget {
  const _AvatarEditor({
    required this.imageBytes,
    required this.fallbackColor,
    required this.displayName,
    required this.onPickImage,
    this.onRemoveImage,
    required this.isSaving,
  });

  final Uint8List? imageBytes;
  final Color fallbackColor;
  final String displayName;
  final VoidCallback onPickImage;
  final VoidCallback? onRemoveImage;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = imageBytes != null;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: isSaving ? null : onPickImage,
            customBorder: const CircleBorder(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: fallbackColor,
                  backgroundImage: hasImage ? MemoryImage(imageBytes!) : null,
                  child: hasImage
                      ? null
                      : const Icon(Icons.person, size: 52, color: Colors.white),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 3,
                      ),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: 18,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                foregroundColor: theme.colorScheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                minimumSize: const Size(140, 44),
                side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                ),
              ),
              onPressed: isSaving ? null : onPickImage,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('\u753b\u50cf\u3092\u9078\u3076'),
            ),
            if (onRemoveImage != null)
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black54,
                ),
                onPressed: isSaving ? null : onRemoveImage,
                icon: const Icon(Icons.delete_outline),
                label: const Text('\u753b\u50cf\u3092\u524a\u9664'),
              ),
          ],
        ),
      ],
    );
  }
}

class _CropScreen extends StatefulWidget {
  final Uint8List image;

  const _CropScreen({required this.image});

  @override
  State<_CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<_CropScreen> {
  final _controller = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Crop(
            image: widget.image,
            controller: _controller,
            onCropped: (image) {
              Navigator.of(context).pop(image);
            },
            withCircleUi: true,
            baseColor: Colors.black,
            maskColor: Colors.black.withOpacity(0.8),
            cornerDotBuilder: (size, edgeAlignment) => const SizedBox.shrink(),
            initialSize: 1.0,
            interactive: true,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(
                  left: 24, right: 24, bottom: 40, top: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'キャンセル',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (_isCropping)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      TextButton(
                        onPressed: () {
                          setState(() => _isCropping = true);
                          _controller.crop();
                        },
                        child: const Text(
                          '完了',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
