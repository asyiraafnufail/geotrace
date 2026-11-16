import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/interaction_model.dart';
import '../../data/repositories/geotrace_repository.dart';
import '../../core/widgets/skeleton_loading.dart';

/// Layar History / Aktivitas untuk melihat siapa saja yang baru bereaksi atau berkomentar
class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => ActivityHistoryScreenState();
}

class ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final _repository = GeoTraceRepository();
  List<InteractionModel> _interactions = [];
  bool _isLoading = true;
  String _selectedScope = 'for_you'; // 'for_you' (notifikasi untuk saya) vs 'group' (semua aktivitas grup)
  String _activeFilter = 'all'; // 'all', 'reactions', 'comments'

  @override
  void initState() {
    super.initState();
    loadActivities();
  }

  Future<void> loadActivities() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repository.fetchRecentInteractions(limit: 60);
      if (mounted) {
        setState(() => _interactions = list);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  List<InteractionModel> get _filteredInteractions {
    final currentUserId = _repository.currentUser?.id;

    // 1. Filter berdasarkan cakupan (Scope)
    List<InteractionModel> scoped;
    if (_selectedScope == 'for_you') {
      // Khusus notifikasi untuk user yang login: interaksi pada check-in milik user oleh orang lain
      scoped = _interactions.where((i) {
        if (currentUserId == null) return false;
        final isMyCheckIn = i.checkInUserId == currentUserId;
        final isNotMe = i.userId != currentUserId;
        return isMyCheckIn && isNotMe;
      }).toList();
    } else {
      // Seluruh interaksi grup perjalanan
      scoped = _interactions;
    }

    // 2. Filter berdasarkan tipe (All, Reactions, Comments)
    if (_activeFilter == 'reactions') {
      return scoped.where((i) => i.reactionType != 'comment').toList();
    }
    if (_activeFilter == 'comments') {
      return scoped.where((i) => i.reactionType == 'comment').toList();
    }
    return scoped;
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0F766E);
    final filtered = _filteredInteractions;
    final currentUserId = _repository.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Activity History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Segmented Scope Switcher: [ For You ] vs [ Group Activity ]
          _buildScopeSelector(primaryColor),

          // Custom Filter Pills: All, Reactions, Comments (Bersih tanpa bulatan Material 3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildCustomFilterChip('all', 'All Activity', Icons.notifications_none_rounded),
                const SizedBox(width: 8),
                _buildCustomFilterChip('reactions', 'Reactions', Icons.favorite_border_rounded),
                const SizedBox(width: 8),
                _buildCustomFilterChip('comments', 'Comments', Icons.chat_bubble_outline_rounded),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Daftar Aktivitas
          Expanded(
            child: _isLoading
                ? const SkeletonActivityList(count: 6)
                : RefreshIndicator(
                    color: primaryColor,
                    onRefresh: loadActivities,
                    child: filtered.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 8,
                              bottom: 120, // Ruang lega untuk floating navbar pill
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return _buildActivityCard(item, currentUserId);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeSelector(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildScopeTab(
              scope: 'for_you',
              title: 'For You',
              icon: Icons.person_rounded,
              primaryColor: primaryColor,
            ),
          ),
          Expanded(
            child: _buildScopeTab(
              scope: 'group',
              title: 'Group Activity',
              icon: Icons.groups_rounded,
              primaryColor: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeTab({
    required String scope,
    required String title,
    required IconData icon,
    required Color primaryColor,
  }) {
    final isSelected = _selectedScope == scope;
    return GestureDetector(
      onTap: () => setState(() => _selectedScope = scope),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? primaryColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? primaryColor : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Custom Filter Chip tanpa bug lingkaran avatar bawaan FilterChip M3
  Widget _buildCustomFilterChip(String key, String label, IconData icon) {
    final isSelected = _activeFilter == key;
    const primaryColor = Color(0xFF0F766E);

    return InkWell(
      onTap: () => setState(() => _activeFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.10),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? primaryColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? primaryColor : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(InteractionModel item, String? currentUserId) {
    final isMe = currentUserId != null && item.userId == currentUserId;
    final isMyCheckIn = currentUserId != null && item.checkInUserId == currentUserId;

    final displayName = item.profile?.displayName;
    final actorName = isMe ? 'You' : (displayName ?? 'Friend');
    final initial = isMe
        ? 'Y'
        : (displayName != null && displayName.isNotEmpty
            ? displayName.substring(0, 1).toUpperCase()
            : 'F');
    final checkInTitle = item.checkInTitle ?? 'a moment';
    final isComment = item.reactionType == 'comment';
    final commentText = item.content;
    final timeStr = _formatRelativeTime(item.createdAt);

    Color badgeColor;
    IconData badgeIcon;
    String verb;

    switch (item.reactionType) {
      case 'love':
        badgeColor = const Color(0xFFEC4899);
        badgeIcon = Icons.favorite_rounded;
        verb = 'loved';
        break;
      case 'fire':
        badgeColor = const Color(0xFFF97316);
        badgeIcon = Icons.local_fire_department_rounded;
        verb = 'fired up';
        break;
      case 'comment':
        badgeColor = const Color(0xFF0284C7);
        badgeIcon = Icons.chat_bubble_rounded;
        verb = 'commented on';
        break;
      case 'like':
      default:
        badgeColor = const Color(0xFF0F766E);
        badgeIcon = Icons.thumb_up_alt_rounded;
        verb = 'liked';
        break;
    }

    String targetPhrase;
    if (isMyCheckIn) {
      targetPhrase = isMe ? 'your own moment' : 'your moment';
    } else {
      final owner = item.checkInOwnerName;
      targetPhrase = owner != null ? "$owner's moment" : "a friend's moment";
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar Profil dengan Badge Reaksi Kecil
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [badgeColor.withOpacity(0.85), badgeColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      badgeIcon,
                      size: 13,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Konten Aktivitas dengan Phrasing Akurat
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                      children: [
                        TextSpan(
                          text: actorName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: ' $verb ',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        TextSpan(
                          text: '$targetPhrase ',
                          style: TextStyle(
                            fontWeight: isMyCheckIn ? FontWeight.bold : FontWeight.w500,
                            color: isMyCheckIn ? const Color(0xFF0F766E) : const Color(0xFF334155),
                          ),
                        ),
                        TextSpan(
                          text: '"$checkInTitle"',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Jika berupa komentar, tampilkan kutipan pesan
                  if (isComment && commentText != null && commentText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        commentText,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),
                  Text(
                    timeStr,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isForYou = _selectedScope == 'for_you';
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 60.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isForYou ? Icons.notifications_none_rounded : Icons.people_outline_rounded,
                size: 54,
                color: const Color(0xFF0F766E),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isForYou ? 'No Personal Notifications' : 'No Group Activity Yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isForYou
                  ? 'When friends like, fire, love, or comment on your check-in moments, they will appear here.'
                  : 'Recent reactions and comments from everyone in your travel group will appear here in real time.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime.toLocal());

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('dd MMM • HH:mm').format(dateTime.toLocal());
    }
  }
}
