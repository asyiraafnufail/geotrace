import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../data/models/check_in_model.dart';
import '../../data/repositories/geotrace_repository.dart';
import '../../core/widgets/geotrace_image.dart';
import '../../core/widgets/full_screen_image_viewer.dart';

class TravelMapScreen extends StatefulWidget {
  final List<CheckInModel>? checkIns;
  final bool isTab;

  const TravelMapScreen({
    super.key,
    this.checkIns,
    this.isTab = false,
  });

  @override
  State<TravelMapScreen> createState() => TravelMapScreenState();
}

class TravelMapScreenState extends State<TravelMapScreen> {
  final _repository = GeoTraceRepository();
  List<CheckInModel> _loadedCheckIns = [];
  Map<String, String> _tripTitles = {};
  bool _isLoading = false;
  String _selectedFilter = 'all'; // 'all' atau tripId tertentu
  final MapController _mapController = MapController();

  void reloadMap() => _fetchMapData();

  @override
  void initState() {
    super.initState();
    if (widget.checkIns != null) {
      _loadedCheckIns = widget.checkIns!;
      _loadTripTitles();
    } else {
      _fetchMapData();
    }
  }

  @override
  void didUpdateWidget(covariant TravelMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checkIns != null) {
      _loadedCheckIns = widget.checkIns!;
      _loadTripTitles();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadTripTitles() async {
    try {
      final trips = await _repository.fetchTrips();
      if (mounted) {
        setState(() {
          _tripTitles = {for (final t in trips) t.id: t.title};
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchMapData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repository.fetchTimeline(page: 0, pageSize: 100);
      final trips = await _repository.fetchTrips();
      if (mounted) {
        setState(() {
          _loadedCheckIns = data;
          _tripTitles = {for (final t in trips) t.id: t.title};
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  List<CheckInModel> get _allCheckIns => widget.checkIns ?? _loadedCheckIns;

  List<CheckInModel> get _filteredAndSortedCheckIns {
    List<CheckInModel> list = _allCheckIns;
    if (_selectedFilter != 'all') {
      list = list.where((c) => c.tripId == _selectedFilter).toList();
    }

    final sorted = List<CheckInModel>.from(list)
      ..sort((a, b) => a.checkedInAt.compareTo(b.checkedInAt));

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredAndSortedCheckIns;
    final validLocations = items.map((c) => LatLng(c.latitude, c.longitude)).toList();

    final center = validLocations.isNotEmpty
        ? validLocations.last
        : const LatLng(-7.7956, 110.3695); // default Yogyakarta

    final uniqueTripIds = _allCheckIns
        .map((c) => c.tripId)
        .whereType<String>()
        .toSet()
        .toList();

    return Scaffold(
      appBar: widget.isTab
          ? null
          : AppBar(
              title: const Text('Travel Route'),
              actions: [
                if (validLocations.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.center_focus_strong_rounded),
                    tooltip: 'Center Map',
                    onPressed: () => _mapController.move(center, 13),
                  ),
              ],
            ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: validLocations.length > 1 ? 12 : 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.geotrace.app',
              ),
              if (validLocations.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: validLocations,
                      strokeWidth: 4.5,
                      color: const Color(0xFF0F766E).withOpacity(0.85),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: List.generate(items.length, (index) {
                  final item = items[index];
                  final stopNumber = index + 1;

                  return Marker(
                    point: LatLng(item.latitude, item.longitude),
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      onTap: () => _showCheckInDetail(context, item, stopNumber),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFEF4444),
                            size: 46,
                          ),
                          Positioned(
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$stopNumber',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),

          // Floating Glass Header saat dalam mode Navbar Tab
          if (widget.isTab)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F766E).withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.map_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Group Travel Map',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            _isLoading ? 'Updating stops...' : '${items.length} stop(s) recorded',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ),
                    if (validLocations.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.center_focus_strong_rounded, color: Color(0xFF0F766E)),
                        tooltip: 'Center Map',
                        onPressed: () => _mapController.move(center, 13),
                      ),
                  ],
                ),
              ),
            ),

          // Bar Filter Trip Modern dengan Rounded Pill Chips
          if (uniqueTripIds.isNotEmpty)
            Positioned(
              top: widget.isTab ? MediaQuery.of(context).padding.top + 80 : 12,
              left: 16,
              right: 16,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      showCheckmark: false,
                      label: const Text('All Stops'),
                      selected: _selectedFilter == 'all',
                      selectedColor: const Color(0xFF0F766E).withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onSelected: (val) {
                        setState(() => _selectedFilter = 'all');
                      },
                    ),
                    const SizedBox(width: 8),
                    ...uniqueTripIds.map((tripId) {
                      final title = _tripTitles[tripId] ??
                          (tripId.length >= 6 ? 'Trip #${tripId.substring(0, 6)}' : 'Trip #$tripId');
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          showCheckmark: false,
                          label: Text(title),
                          selected: _selectedFilter == tripId,
                          selectedColor: const Color(0xFF0F766E).withOpacity(0.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onSelected: (val) {
                            setState(() => _selectedFilter = tripId);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showCheckInDetail(BuildContext context, CheckInModel item, int stopNumber) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrWide = screenWidth >= 600;

    if (isDesktopOrWide) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 660),
            child: _buildCheckInDetailContent(ctx, item, stopNumber, isDialog: true),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 540,
          ),
          child: _buildCheckInDetailContent(ctx, item, stopNumber, isDialog: false),
        ),
      );
    }
  }

  Widget _buildCheckInDetailContent(
    BuildContext context,
    CheckInModel item,
    int stopNumber, {
    required bool isDialog,
  }) {
    final tripTitle = (item.tripId != null && _tripTitles.containsKey(item.tripId))
        ? _tripTitles[item.tripId]
        : null;
    final timeStr = DateFormat('dd MMM yyyy • HH:mm').format(item.checkedInAt.toLocal());
    final displayName = item.profile?.displayName ?? 'Friend';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isDialog
            ? BorderRadius.circular(28)
            : const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: isDialog
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle khusus untuk BottomSheet di HP
            if (!isDialog)
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

            // Header Bar: Stop Badge + Trip Tag + Close Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pin_drop_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Stop #$stopNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (tripTitle != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F4F1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF99F6E4)),
                    ),
                    child: Text(
                      tripTitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: Colors.grey.shade600,
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Judul Momen / Tempat
            Text(
              item.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),

            // Lokasi & Alamat
            if (item.locationName != null && item.locationName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        item.locationName!,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Metadata: Tanggal Check-in & Pembuat
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 5),
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 14),
                Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            // Catatan Perjalanan (Notes)
            if (item.note != null && item.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  item.note!,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],

            // Galeri Foto Momen
            if (item.photos.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.photo_library_rounded, size: 15, color: Color(0xFF0F766E)),
                  const SizedBox(width: 6),
                  Text(
                    'Photos (${item.photos.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: item.photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (ctx, pIdx) {
                    final photoUrl = item.photos[pIdx].photoUrl;
                    final tag = 'map_photo_${item.id}_$pIdx';

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 130,
                        height: 130,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                opaque: false,
                                pageBuilder: (_, animation, __) => FullScreenImageViewer(
                                  imageUrl: photoUrl,
                                  heroTag: tag,
                                  title: '${item.title} (${pIdx + 1}/${item.photos.length})',
                                ),
                                transitionsBuilder: (_, anim, __, child) =>
                                    FadeTransition(opacity: anim, child: child),
                              ),
                            );
                          },
                          child: GeoTraceCachedImage(
                            imageUrl: photoUrl,
                            heroTag: tag,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Tombol Aksi: Pusatkan Peta ke Titik Ini
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: const BorderSide(color: Color(0xFF0F766E), width: 1.2),
                ),
                icon: const Icon(Icons.center_focus_strong_rounded, size: 16),
                label: const Text(
                  'Center on Map',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _mapController.move(LatLng(item.latitude, item.longitude), 15);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
