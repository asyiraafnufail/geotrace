import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/check_in_model.dart';
import '../../data/repositories/geotrace_repository.dart';
import '../../core/widgets/geotrace_image.dart';
import '../../core/widgets/full_screen_image_viewer.dart';
import '../../core/widgets/skeleton_loading.dart';
import '../../core/storage/offline_queue_service.dart';
import '../checkin/new_checkin_screen.dart';
import '../map/travel_map_screen.dart';
import '../profile/profile_sheet.dart';
import 'widgets/comment_bottom_sheet.dart';
import 'widgets/animated_reaction_button.dart';

class TimelineScreen extends StatefulWidget {
  final bool isEmbeddedTab;

  const TimelineScreen({super.key, this.isEmbeddedTab = false});

  @override
  TimelineScreenState createState() => TimelineScreenState();
}

class TimelineScreenState extends State<TimelineScreen> {
  final _repository = GeoTraceRepository();
  final List<CheckInModel> _items = [];
  final ScrollController _scrollController = ScrollController();

  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  int _offlineDraftsCount = 0;
  bool _isSyncingDrafts = false;

  @override
  void initState() {
    super.initState();
    _checkOfflineDrafts();
    _fetchPage(0);
    _scrollController.addListener(_onScroll);
  }

  /// Dipanggil dari Navbar saat tab diklik ulang
  void scrollToTopAndRefresh() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
    refreshTimeline();
  }

  /// Dipanggil setelah check-in baru berhasil
  Future<void> refreshTimeline() async {
    _hasMore = true;
    await _checkOfflineDrafts();
    await _fetchPage(0);
  }

  Future<void> _checkOfflineDrafts() async {
    final drafts = await OfflineQueueService.getDrafts();
    if (mounted) setState(() => _offlineDraftsCount = drafts.length);
  }

  Future<void> _syncOfflineDrafts() async {
    if (_isSyncingDrafts) return;
    setState(() => _isSyncingDrafts = true);
    try {
      final count = await OfflineQueueService.syncAll(_repository);
      if (mounted && count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Text('$count offline check-in(s) synced to cloud!'),
          ),
        );
        await _fetchPage(0);
      }
    } catch (_) {}
    await _checkOfflineDrafts();
    if (mounted) setState(() => _isSyncingDrafts = false);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchPage(_currentPage + 1);
    }
  }

  Future<void> _fetchPage(int page) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final newItems = await _repository.fetchTimeline(page: page);
      if (mounted) {
        setState(() {
          if (page == 0) {
            _items.clear();
          }
          _items.addAll(newItems);
          _currentPage = page;
          if (newItems.length < 15) {
            _hasMore = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Text('Failed to load timeline: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addReaction(CheckInModel item, String reactionType) async {
    try {
      await _repository.addInteraction(checkInId: item.id, reactionType: reactionType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Text('Reaction $reactionType sent!'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Text('Error: $e'),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteCheckIn(CheckInModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Check-in?'),
        content: const Text(
          'This entry and all associated photos will be permanently deleted from the cloud server to save storage space.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _repository.deleteCheckIn(item.id);
        setState(() {
          _items.removeWhere((i) => i.id == item.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              content: const Text('Check-in and photos removed from server.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              content: Text('Failed to delete: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _openCommentSheet(CheckInModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentBottomSheet(
        checkIn: item,
        onCommentAdded: () {
          _fetchPage(0);
        },
      ),
    );
  }

  void _openImageViewer(String photoUrl, String heroTag, String title) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => FullScreenImageViewer(
          imageUrl: photoUrl,
          heroTag: heroTag,
          title: title,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _openNewCheckIn(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewCheckInScreen(
          onCheckInSuccess: () {
            _checkOfflineDrafts();
            _fetchPage(0);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F766E).withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'GeoTrace',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: widget.isEmbeddedTab
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.map_outlined),
                  tooltip: 'View Travel Map',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TravelMapScreen(checkIns: _items)),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.person_outline),
                  tooltip: 'Profile & Storage Settings',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const ProfileSheet(),
                    );
                  },
                ),
              ],
      ),
      body: Column(
        children: [
          // Banner Antrean Check-in Offline (Modern Pill Style)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _offlineDraftsCount > 0
                ? Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 20, color: Color(0xFFB45309)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$_offlineDraftsCount check-in(s) saved offline on device',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF92400E),
                            backgroundColor: Colors.white.withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isSyncingDrafts ? null : _syncOfflineDrafts,
                          icon: _isSyncingDrafts
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync_rounded, size: 16),
                          label: const Text('Sync Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF0F766E),
              onRefresh: () async {
                _hasMore = true;
                await _syncOfflineDrafts();
                await _fetchPage(0);
              },
              child: _items.isEmpty && _isLoading
                  ? const SkeletonTimelineList(count: 3)
                  : _items.isEmpty && !_isLoading
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 80.0),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F766E).withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.explore_rounded,
                                      size: 54,
                                      color: Color(0xFF0F766E),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'No travel check-ins yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start your adventure! Create your first check-in and share exciting moments with friends.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () => _openNewCheckIn(context),
                                    icon: const Icon(Icons.add_location_alt_rounded),
                                    label: const Text('Create First Check-in'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(
                            top: 10,
                            bottom: widget.isEmbeddedTab ? 100 : 80,
                          ),
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _items.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: ShimmerLoading(
                                  child: SkeletonTimelineCard(),
                                ),
                              );
                            }

                            final item = _items[index];
                            return _TimelineCardItem(
                              key: ValueKey(item.id),
                              item: item,
                              currentUserId: _repository.currentUser?.id,
                              onReaction: (reaction) => _addReaction(item, reaction),
                              onDelete: () => _confirmDeleteCheckIn(item),
                              onCommentTap: () => _openCommentSheet(item),
                              onPhotoTap: (url, tag, title) => _openImageViewer(url, tag, title),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.isEmbeddedTab
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openNewCheckIn(context),
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Check-in'),
            ),
    );
  }
}

/// Widget Card Timeline Modern dengan Rounded Corners, Carousel Dot Indicator & Micro-interactions
class _TimelineCardItem extends StatefulWidget {
  final CheckInModel item;
  final String? currentUserId;
  final Function(String) onReaction;
  final VoidCallback onDelete;
  final VoidCallback onCommentTap;
  final Function(String url, String tag, String title) onPhotoTap;

  const _TimelineCardItem({
    super.key,
    required this.item,
    required this.currentUserId,
    required this.onReaction,
    required this.onDelete,
    required this.onCommentTap,
    required this.onPhotoTap,
  });

  @override
  State<_TimelineCardItem> createState() => _TimelineCardItemState();
}

class _TimelineCardItemState extends State<_TimelineCardItem> {
  int _activePhotoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isOwner = item.userId == widget.currentUserId;
    final dateFormat = DateFormat('dd MMM • HH:mm');
    final formattedDate = dateFormat.format(item.checkedInAt.toLocal());
    final displayName = item.profile?.displayName ?? 'Friend';
    final initial = displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header User & Info Lokasi
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F766E).withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (item.locationName != null && item.locationName!.isNotEmpty) ...[
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TravelMapScreen(
                                        checkIns: [item],
                                        isTab: false,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6F4F1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.location_on_rounded,
                                        size: 11,
                                        color: Color(0xFF0F766E),
                                      ),
                                      const SizedBox(width: 3),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 120),
                                        child: Text(
                                          item.locationName!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F766E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isOwner)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz_rounded, size: 22, color: Colors.grey.shade500),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        if (val == 'delete') widget.onDelete();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Delete Check-in', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Foto Carousel Modern dengan Dot Indicators
            if (item.photos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 250,
                    child: Stack(
                      children: [
                        PageView.builder(
                          itemCount: item.photos.length,
                          onPageChanged: (idx) {
                            setState(() => _activePhotoIndex = idx);
                          },
                          itemBuilder: (context, pIndex) {
                            final photo = item.photos[pIndex];
                            final tag = '${item.id}_photo_$pIndex';

                            return GestureDetector(
                              onTap: () => widget.onPhotoTap(
                                photo.photoUrl,
                                tag,
                                '${item.title} (${pIndex + 1}/${item.photos.length})',
                              ),
                              child: GeoTraceCachedImage(
                                imageUrl: photo.photoUrl,
                                heroTag: tag,
                                width: double.infinity,
                                height: 250,
                              ),
                            );
                          },
                        ),
                        // Badge Counter di Pojok Kanan Atas
                        if (item.photos.length > 1)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '${_activePhotoIndex + 1}/${item.photos.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        // Dots Indicator di Bawah Tengah
                        if (item.photos.length > 1)
                          Positioned(
                            bottom: 12,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                item.photos.length,
                                (dotIdx) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: _activePhotoIndex == dotIdx ? 16 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _activePhotoIndex == dotIdx
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

            // Judul & Catatan
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (item.note != null && item.note!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.note!,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Divider Pemisah
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

            // Bar Interaksi (Like, Love, Fire, Komentar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  AnimatedReactionButton(
                    icon: Icons.thumb_up_alt_outlined,
                    label: 'Like',
                    color: const Color(0xFF0F766E),
                    onPressed: () => widget.onReaction('like'),
                  ),
                  AnimatedReactionButton(
                    icon: Icons.favorite_border_rounded,
                    label: 'Love',
                    color: const Color(0xFFEC4899),
                    onPressed: () => widget.onReaction('love'),
                  ),
                  AnimatedReactionButton(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Fire',
                    color: const Color(0xFFF97316),
                    onPressed: () => widget.onReaction('fire'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: widget.onCommentTap,
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: Text(
                      item.interactions.where((i) => i.reactionType == 'comment').isNotEmpty
                          ? '${item.interactions.where((i) => i.reactionType == 'comment').length} Comments'
                          : 'Comment',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
