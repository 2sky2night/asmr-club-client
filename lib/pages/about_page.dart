import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 关于页面
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse('https://github.com/2sky2night/asmr-club-client');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<String> _loadChangelog() async {
    try {
      return await rootBundle.loadString('CHANGELOG.md');
    } catch (e) {
      return '无法加载更新日志';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
            Icon(Icons.headphones, size: 80, color: Theme.of(context).primaryColor),
            const SizedBox(height: 24),
            const Text(
              'ASMR Club',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder<String>(
              future: _getVersion(),
              builder: (context, snapshot) {
                return Text(
                  '版本: ${snapshot.data ?? '1.0.0'}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                );
              },
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FutureBuilder<String>(
                  future: _loadChangelog(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return MarkdownBody(
                      data: snapshot.data ?? '',
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: _launchUrl,
              icon: const Icon(Icons.code),
              label: const Text('代码仓库'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
    );
  }

  Future<String> _getVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      return '${info.version} (${info.buildNumber})';
    } catch (e) {
      return '1.0.0 (1)';
    }
  }
}
