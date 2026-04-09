import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/module_download_service.dart';
import '../widgets/delete_account_dialog.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userEmail = '';
  static const String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService().getCachedUser();
    if (mounted) {
      setState(() {
        _userEmail = (user?['email'] as String?) ?? '';
      });
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Local Cache', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will delete all downloaded module bundles. They will be re-downloaded on next launch.',
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final freed = await ModuleDownloadService.clearLocalCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(freed > 0
            ? 'Cache cleared (${(freed / 1024).toStringAsFixed(0)} KB freed)'
            : 'Cache cleared'),
        backgroundColor: const Color(0xFF16213E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // ── Account Section ────────────────────────────────────────────
          _sectionHeader('Account'),
          _tile(
            icon: Icons.person_outline,
            title: _userEmail.isNotEmpty ? _userEmail : 'Your account',
            subtitle: 'Signed in',
            onTap: null,
          ),
          _tile(
            icon: Icons.delete_outline,
            title: 'Delete Account',
            titleColor: Colors.redAccent,
            iconColor: Colors.redAccent,
            onTap: () => showDialog(
              context: context,
              builder: (_) => const DeleteAccountDialog(),
            ),
          ),
          _tile(
            icon: Icons.logout,
            title: 'Log Out',
            onTap: _logout,
          ),

          const SizedBox(height: 8),

          // ── Legal Section ──────────────────────────────────────────────
          _sectionHeader('Legal'),
          _tile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            trailing: const Icon(Icons.chevron_right, color: Colors.white24),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
          _tile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            trailing: const Icon(Icons.chevron_right, color: Colors.white24),
            onTap: () => _showTermsDialog(),
          ),

          const SizedBox(height: 8),

          // ── About Section ──────────────────────────────────────────────
          _sectionHeader('About'),
          _tile(
            icon: Icons.info_outline,
            title: 'App Version',
            subtitle: _appVersion,
            onTap: null,
          ),
          _tile(
            icon: Icons.email_outlined,
            title: 'Contact Support',
            subtitle: 'support@colligence.in',
            onTap: null,
          ),

          const SizedBox(height: 8),

          // ── Data Section ───────────────────────────────────────────────
          _sectionHeader('Data'),
          _tile(
            icon: Icons.cleaning_services_outlined,
            title: 'Clear Local Cache',
            subtitle: 'Delete downloaded module bundles',
            onTap: _clearCache,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF6C63FF),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Color? iconColor,
    Widget? trailing,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? Colors.white70, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? Colors.white,
            fontSize: 15,
          ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 13))
            : null,
        trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: Colors.white24) : null),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Terms of Service', style: TextStyle(color: Colors.white)),
        content: const SingleChildScrollView(
          child: Text(
            'By using the Foundry App, you agree to use it solely for its intended purpose of field data collection within your organization.\n\n'
            'You agree not to reverse engineer, misuse, or share your login credentials with unauthorized individuals.\n\n'
            'All data collected belongs to your organization. Colligence acts as a data processor on your behalf.\n\n'
            'For questions, contact support@colligence.in.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF6C63FF))),
          ),
        ],
      ),
    );
  }
}
