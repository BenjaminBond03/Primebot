import 'package:flutter/material.dart';
import 'package:primebot_frontend/services/app_settings.dart';
import 'package:primebot_frontend/services/notification_service.dart';

const _primaryBlue = Color(0xFF1565C0);
const _darkText = Color(0xFF1A1A2E);
const _greyText = Color(0xFF757575);

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _enabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await AppSettings.instance.notificationsEnabled;
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _isLoading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    await AppSettings.instance.setNotificationsEnabled(value);
    if (value) {
      await NotificationService.instance.requestPermissions();
    }
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
          'Notifications',
          style: TextStyle(color: _darkText, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  activeThumbColor: _primaryBlue,
                  value: _enabled,
                  onChanged: _toggle,
                  title: const Text(
                    'Task Reminders',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _darkText),
                  ),
                  subtitle: const Text(
                    'Get notified when a task or deadline you added is due',
                    style: TextStyle(fontSize: 12, color: _greyText),
                  ),
                ),
              ),
            ),
    );
  }
}
