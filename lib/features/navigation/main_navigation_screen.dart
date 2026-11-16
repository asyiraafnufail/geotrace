import 'package:flutter/material.dart';
import '../timeline/timeline_screen.dart';
import '../map/travel_map_screen.dart';
import '../history/activity_history_screen.dart';
import '../profile/profile_screen.dart';
import '../checkin/new_checkin_screen.dart';

/// Layar Navigasi Utama dengan Modern Floating Pill Bar & Tombol Check-in (+) Terintegrasi
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Key untuk memicu refresh
  final GlobalKey<TimelineScreenState> _timelineKey = GlobalKey<TimelineScreenState>();
  final GlobalKey<TravelMapScreenState> _mapKey = GlobalKey<TravelMapScreenState>();
  final GlobalKey<ActivityHistoryScreenState> _historyKey = GlobalKey<ActivityHistoryScreenState>();

  void _onTabSelected(int index) {
    if (_currentIndex == index) {
      if (index == 0) {
        // Jika tab timeline ditekan lagi saat sedang aktif, scroll ke atas & refresh
        _timelineKey.currentState?.scrollToTopAndRefresh();
      } else if (index == 1) {
        // Jika tab map ditekan lagi, perbarui rute & titik lokasi
        _mapKey.currentState?.reloadMap();
      } else if (index == 2) {
        // Jika tab history ditekan lagi saat aktif, refresh aktivitas terbaru
        _historyKey.currentState?.loadActivities();
      }
    } else {
      setState(() => _currentIndex = index);
      if (index == 1) {
        _mapKey.currentState?.reloadMap();
      }
    }
  }

  void _openNewCheckIn() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewCheckInScreen(
          onCheckInSuccess: () {
            // Refresh seluruh tab setelah check-in sukses
            _timelineKey.currentState?.refreshTimeline();
            _mapKey.currentState?.reloadMap();
            _historyKey.currentState?.loadActivities();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Memungkinkan konten scroll lembut di bawah pill navbar
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TimelineScreen(key: _timelineKey, isEmbeddedTab: true),
          TravelMapScreen(key: _mapKey, isTab: true),
          ActivityHistoryScreen(key: _historyKey),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildModernFloatingNavBar(context),
    );
  }

  /// Modern Pill-style Bottom Navigation Bar dengan Center Button (+) & 4 Tab
  Widget _buildModernFloatingNavBar(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomPadding > 0 ? bottomPadding : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withOpacity(0.12),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Tab 0: Timeline
              _buildNavItem(
                index: 0,
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore_rounded,
                label: 'Timeline',
              ),

              // Tab 1: Travel Map
              _buildNavItem(
                index: 1,
                icon: Icons.map_outlined,
                activeIcon: Icons.map_rounded,
                label: 'Map',
              ),

              // Center Check-in (+) Action Button
              _buildCenterCheckInButton(),

              // Tab 2: Activity History
              _buildNavItem(
                index: 2,
                icon: Icons.notifications_none_rounded,
                activeIcon: Icons.notifications_rounded,
                label: 'History',
              ),

              // Tab 3: Profile
              _buildNavItem(
                index: 3,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tombol Check-in Pusat (+) Modern Berbentuk Lingkaran dengan Gradient Deep Teal
  Widget _buildCenterCheckInButton() {
    const primaryColor = Color(0xFF0F766E);

    return InkWell(
      onTap: _openNewCheckIn,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    const primaryColor = Color(0xFF0F766E);

    return InkWell(
      onTap: () => _onTabSelected(index),
      borderRadius: BorderRadius.circular(20),
      splashColor: primaryColor.withOpacity(0.08),
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 12 : 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? primaryColor : Colors.grey.shade500,
              size: 23,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
