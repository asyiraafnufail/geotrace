import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/storage/custom_cache_manager.dart';
import '../../core/widgets/skeleton_loading.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/geotrace_repository.dart';

/// Halaman Profil Modern dengan Ringkasan Statistik, Manajemen Cache, dan Edit Profil
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repository = GeoTraceRepository();
  ProfileModel? _profile;
  int _totalCheckIns = 0;
  int _totalTrips = 0;
  bool _isLoading = true;
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final p = await _repository.getCurrentProfile();
      final trips = await _repository.fetchTrips();
      final timeline = await _repository.fetchTimeline(page: 0, pageSize: 100);
      final myCheckIns = timeline.where((c) => c.userId == _repository.currentUser?.id).length;

      if (mounted) {
        setState(() {
          _profile = p;
          _totalTrips = trips.length;
          _totalCheckIns = myCheckIns;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleClearCache() async {
    setState(() => _isClearingCache = true);
    try {
      await GeoTraceCacheManager.clearCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Local photo cache cleared! (Cloud photos remain safe)'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Failed to clear cache: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearingCache = false);
    }
  }

  Future<void> _openEditProfileDialog() async {
    final currentName =
        _profile?.displayName ?? _repository.currentUser?.email?.split('@').first ?? '';
    final currentBio = _profile?.bio ?? '';

    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _EditProfileDialog(
        initialName: currentName,
        initialBio: currentBio,
        onSave: (name, bio) => _repository.updateProfile(displayName: name, bio: bio),
      ),
    );

    if (updated == true && mounted) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Profile updated successfully!'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _repository.currentUser;
    final displayName = _profile?.displayName ?? user?.email?.split('@').first ?? 'Friend';
    final email = user?.email ?? '-';
    final username = _profile?.username ?? user?.email?.split('@').first ?? 'user';

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, size: 26),
            tooltip: 'Edit Profile',
            onPressed: _openEditProfileDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const SkeletonProfileView()
          : RefreshIndicator(
              color: const Color(0xFF0F766E),
              onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 120),
          child: Column(
            children: [
              // Header Card Profil
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    children: [
                      // Avatar Modern dengan Border Lingkaran
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0F766E), width: 2.5),
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFF0F766E),
                          child: Text(
                            displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        displayName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4F1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '@$username',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      if (_profile?.bio != null && _profile!.bio!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            '"${_profile!.bio!}"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade800,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Statistik Jejak Perjalanan
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.pin_drop_rounded,
                      value: '$_totalCheckIns',
                      label: 'My Check-ins',
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.card_travel_rounded,
                      value: '$_totalTrips',
                      label: 'Group Trips',
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Card Manajemen Cache & Memori HP
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F4F1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.sd_card_outlined, color: Color(0xFF0F766E), size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Local Photo Cache',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  'Automatic limit: 150 MB (LRU)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Photos you view are cached temporarily on your device to save internet data when revisited. You can clear this cache anytime.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isClearingCache ? null : _handleClearCache,
                          icon: _isClearingCache
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.cleaning_services_rounded, size: 18),
                          label: const Text('Clear Local Photo Cache'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tombol Logout Modern
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.red.shade100),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        title: const Text('Sign Out of GeoTrace?'),
                        content: const Text('You can sign back in anytime with your email & password.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await Future.delayed(const Duration(milliseconds: 150));
                      await Supabase.instance.client.auth.signOut();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final String initialName;
  final String initialBio;
  final Future<void> Function(String name, String? bio) onSave;

  const _EditProfileDialog({
    required this.initialName,
    required this.initialBio,
    required this.onSave,
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
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
