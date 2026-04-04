import 'package:flutter/material.dart';

class MobileLayout extends StatelessWidget {
  final int currentIndex;
  final Function(int) onIndexChanged;
  final List<Widget> pages;

  const MobileLayout({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.pages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, minHeight: 480),
        child: pages[currentIndex],
      ),
      bottomNavigationBar: Container(
        height: 80,
        color: theme.scaffoldBackgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _navIcon(context, Icons.description_outlined, 0),
            _navIcon(context, Icons.search, 1),
            _navIcon(context, Icons.folder_outlined, 2),
            _navIcon(context, Icons.settings_outlined, 3),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(BuildContext context, IconData icon, int index) {
    bool isActive = currentIndex == index;

    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () => onIndexChanged(index),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isActive ? primaryColor : Colors.transparent,
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
