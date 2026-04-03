import 'package:flutter/material.dart';

import '../pages/cluster_page.dart';
import '../pages/home_page.dart';
import '../pages/search_page.dart';
import '../pages/settings_page.dart';

import 'theme_palette.dart';

class LayoutManager extends StatefulWidget {
  const LayoutManager({super.key});

  @override
  State<LayoutManager> createState() => _LayoutManagerState();
}

class _LayoutManagerState extends State<LayoutManager> {
  int _currentIndex = 0;

  // This list maps your icons to the actual pages
  final List<Widget> _pages = [
    const HomePage(),
    const SearchPage(),
    const ClusterPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        //breakpoint 600px
        if (constraints.maxWidth < 600) {
          return _buildMobileLayout();
        } else {
          return _buildDesktopLayout();
        }
      },
    );
  }

  //mobile layout
  Widget _buildMobileLayout() {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        height: 80,
        color: AppTheme.neutral,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _navIcon(Icons.description_outlined, 0),
            _navIcon(Icons.search, 1),
            _navIcon(Icons.folder_outlined, 2),
            _navIcon(Icons.settings_outlined, 3),
          ],
        ),
      ),
    );
  }

  //desktop layout
  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 80,
            color: const Color(0xFF1A1A1A), // Slightly lighter than background
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _navIcon(Icons.description_outlined, 0),
                const SizedBox(height: 20),
                _navIcon(Icons.search, 1),
                const SizedBox(height: 20),
                _navIcon(Icons.folder_outlined, 2),
                const SizedBox(height: 20),
                _navIcon(Icons.settings_outlined, 3),
              ],
            ),
          ),
          // Main Content Area
          Expanded(child: _pages[_currentIndex]),
        ],
      ),
    );
  }

  // Custom Navigation Icon Widget
  Widget _navIcon(IconData icon, int index) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.black : Colors.grey,
          size: 28,
        ),
      ),
    );
  }
}
