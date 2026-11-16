import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/storage/custom_cache_manager.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/geotrace_repository.dart';

/// Modal dialog / sheet profil pengguna dan manajemen cache lokal HP
class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key});

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  final _repository = GeoTraceRepository();
  ProfileModel? _profile;
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _repository.getCurrentProfile();
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
  }

  Future<void> _openEditProfileDialog() async {
    final currentName =
        _profile?.displayName ?? _repository.currentUser?.email?.split('@').first ?? '';
    final currentBio = _profile?.bio ?? '';

    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _EditProfileDialogSheet(
        initialName: currentName,
        initialBio: currentBio,
        onSave: (name, bio) => _repository.updateProfile(displayName: name, bio: bio),
      ),
    );

    if (updated == true && mounted) {
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    }
  }

  Future<void> _handleClearCache() async {
    setState(() => _isClearingCache = true);
    try {
      await GeoTraceCacheManager.clearCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Local photo cache cleared! (Cloud photos remain safe)'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear cache: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearingCache = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _repository.currentUser;
    final displayName = _profile?.displayName ?? user?.email?.split('@').first ?? 'Friend';
    final email = user?.email ?? '-';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Info Profil
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF0F766E),
                child: Text(
                  displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'F',
                  style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      email,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    if (_profile?.bio != null && _profile!.bio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _profile!.bio!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade800,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Edit Profile',
                onPressed: _openEditProfileDialog,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),

          // Card Manajemen Memori HP (Efisiensi Storage)
          Card(
            elevation: 0,
            color: Colors.grey.shade100,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cleaning_services_outlined, size: 20, color: Color(0xFF0F766E)),
                      SizedBox(width: 8),
                      Text(
                        'Local Device Storage (Disk Cache)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cache limit: max ~150 MB (automatic LRU). You can clear this cache anytime if your device storage is full.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F766E),
                        side: const BorderSide(color: Color(0xFF0F766E)),
                      ),
                      onPressed: _isClearingCache ? null : _handleClearCache,
                      icon: _isClearingCache
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: const Text('Clear Local Photo Cache', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tombol Logout
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade200),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign Out'),
            onPressed: () async {
              Navigator.pop(context);
              await Future.delayed(const Duration(milliseconds: 150));
              await Supabase.instance.client.auth.signOut();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _EditProfileDialogSheet extends StatefulWidget {
  final String initialName;
  final String initialBio;
  final Future<void> Function(String name, String? bio) onSave;

  const _EditProfileDialogSheet({
    required this.initialName,
    required this.initialBio,
    required this.onSave,
  });

  @override
  State<_EditProfileDialogSheet> createState() => _EditProfileDialogSheetState();
}

class _EditProfileDialogSheetState extends State<_EditProfileDialogSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _bioController = TextEditingController(text: widget.initialBio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Display Name cannot be empty.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final bio = _bioController.text.trim();
      await widget.onSave(name, bio.isEmpty ? null : bio);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to update profile: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Edit Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name *',
                hintText: 'Name visible to friends',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _bioController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'E.g., Coffee lover & casual traveler',
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
          ),
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save Profile'),
        ),
      ],
    );
  }
}
