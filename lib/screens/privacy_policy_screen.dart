import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  String _html = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    final html = await rootBundle.loadString('assets/legal/privacy-policy.html');
    if (mounted) setState(() { _html = html; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildPolicyContent(),
            ),
    );
  }

  Widget _buildPolicyContent() {
    // Parse the HTML content and render as native Flutter widgets
    // This avoids using a WebView for static content (better for 4.2 compliance)
    final sections = _parseSections(_html);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Privacy Policy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Effective Date: April 9, 2026',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
        const SizedBox(height: 20),
        ...sections,
      ],
    );
  }

  List<Widget> _parseSections(String html) {
    // Simple approach: extract text content and render natively
    final widgets = <Widget>[];

    // Remove HTML tags for a clean text rendering
    final stripped = html
        .replaceAll(RegExp(r'<style>.*?</style>', dotAll: true), '')
        .replaceAll(RegExp(r'<head>.*?</head>', dotAll: true), '')
        .replaceAll(RegExp(r'<h1>.*?</h1>', dotAll: true), '') // skip h1, we render manually
        .replaceAll(RegExp(r'<p class="effective">.*?</p>', dotAll: true), ''); // skip, rendered manually

    // Extract h2 sections
    final sectionPattern = RegExp(r'<h2>(.*?)</h2>\s*<div class="section">(.*?)</div>', dotAll: true);
    for (final match in sectionPattern.allMatches(stripped)) {
      final heading = match.group(1)!.trim();
      final body = match.group(2)!
          .replaceAllMapped(RegExp(r'<li>\s*<strong>(.*?)</strong>', dotAll: true), (m) => '\n- ${m.group(1)}')
          .replaceAll(RegExp(r'<li>'), '\n- ')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();

      widgets.add(const SizedBox(height: 22));
      widgets.add(Text(
        heading,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ));
      widgets.add(const SizedBox(height: 10));
      widgets.add(Text(
        body,
        style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14, height: 1.5),
      ));
    }

    return widgets;
  }
}
