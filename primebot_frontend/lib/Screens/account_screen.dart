import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:primebot_frontend/Screens/change_password_screen.dart';
import 'package:primebot_frontend/Screens/edit_profile_screen.dart';
import 'package:primebot_frontend/Screens/notification_settings_screen.dart';
import 'package:primebot_frontend/services/user_session.dart';

const _primaryBlue = Color(0xFF1565C0);
const _darkText = Color(0xFF1A1A2E);
const _greyText = Color(0xFF757575);

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  int? _userId;
  String _name = 'UTAS Student';
  String _email = 'Not signed in';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await UserSession.instance.getUser();
    if (!mounted || user == null) return;
    setState(() {
      _userId = user['id'] as int;
      _name = user['username'] as String;
      _email = user['email'] as String;
    });
  }

  void _requireLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please log in first')),
    );
  }

  Future<void> _openEditProfile() async {
    final userId = _userId;
    if (userId == null) {
      _requireLogin();
      return;
    }
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(userId: userId, username: _name, email: _email),
      ),
    );
    if (updated == true) _loadCurrentUser();
  }

  Future<void> _openChangePassword() async {
    final userId = _userId;
    if (userId == null) {
      _requireLogin();
      return;
    }
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ChangePasswordScreen(userId: userId)),
    );
    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
    }
  }

  void _openNotificationSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _primaryBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('About PrimeBot'),
          ],
        ),
        content: const Text(
          'PrimeBot is an AI-powered support assistant for University of '
          'Applied Science, Ghana (UTAS) students. It answers questions '
          'using content drawn directly from the official UTAS website, '
          'and helps with staying on top of tasks and finding your way '
          'around campus.\n\nVersion 1.0.0',
          style: TextStyle(fontSize: 13, height: 1.5, color: _darkText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Help & Support'),
        content: const Text(
          'You can ask PrimeBot directly in the chat for most questions '
          'about admissions, courses, and campus life.\n\n'
          'For anything else, reach out to the UTAS support team by email.',
          style: TextStyle(fontSize: 13, height: 1.5, color: _darkText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              launchUrl(Uri.parse('mailto:support@utas.edu.gh'));
            },
            child: const Text('Email Support'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _darkText),
        title: const Text(
          'Account',
          style: TextStyle(
            color: _darkText,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 28),
          _buildSectionCard([
            _buildTile(
              icon: Icons.person_outline,
              label: 'Edit Profile',
              onTap: _openEditProfile,
            ),
            _buildTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: _openNotificationSettings,
            ),
            _buildTile(
              icon: Icons.lock_outline,
              label: 'Privacy & Security',
              onTap: _openChangePassword,
            ),
          ]),
          const SizedBox(height: 16),
          _buildSectionCard([
            _buildTile(
              icon: Icons.info_outline,
              label: 'About PrimeBot',
              onTap: _showAboutDialog,
            ),
            _buildTile(
              icon: Icons.help_outline,
              label: 'Help & Support',
              onTap: _showHelpDialog,
            ),
          ]),
          const SizedBox(height: 16),
          _buildSectionCard([
            _buildTile(
              icon: Icons.logout_rounded,
              label: 'Log Out',
              color: Colors.redAccent,
              onTap: () => _confirmLogout(context),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 32,
          backgroundColor: _primaryBlue,
          child: Icon(Icons.person_rounded, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _darkText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _email,
                style: const TextStyle(fontSize: 13, color: _greyText),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i < tiles.length - 1)
              const Divider(height: 1, indent: 56, color: Color(0xFFF0F0F0)),
          ],
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? _primaryBlue, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color ?? _darkText,
        ),
      ),
      trailing: color == null
          ? const Icon(Icons.chevron_right_rounded, color: Color(0xFFBDBDBD))
          : null,
      onTap: onTap,
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await UserSession.instance.clear();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
