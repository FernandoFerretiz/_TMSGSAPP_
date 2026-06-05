part of dashboard;

class _MainMenu extends StatelessWidget {
  const _MainMenu({
    required this.onSelected,
    Key? key,
  }) : super(key: key);

  final Function(int index, SelectionButtonData value) onSelected;

  @override
  Widget build(BuildContext context) {
    return SelectionButton(
      data: [
        SelectionButtonData(
          activeIcon: Icons.home,
          icon: Icons.home_outlined,
          label: "Home",
        ),
        SelectionButtonData(
          activeIcon: Icons.notifications,
          icon: Icons.notifications_outlined,
          label: "Notifications",
          totalNotif: 100,
        ),
        SelectionButtonData(
          activeIcon: Icons.check_circle,
          icon: Icons.check_circle_outline,
          label: "Task",
          totalNotif: 20,
        ),
        SelectionButtonData(
          activeIcon: Icons.settings,
          icon: Icons.settings_outlined,
          label: "Settings",
        ),
      ],
      onSelected: onSelected,
    );
  }
}
