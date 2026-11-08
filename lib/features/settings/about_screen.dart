import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/crash_log.dart';
import '../../core/output.dart';

const appVersion = '1.0.0';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _shareLog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await CrashLog.path();
    if (path == null) {
      messenger.showSnackBar(const SnackBar(content: Text('No problems have been logged.')));
      return;
    }
    await Output.shareFile(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        children: [
          const ListTile(title: Text('Canvo Edit'), subtitle: Text('Version $appVersion')),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Your privacy'),
            subtitle: Text(
              'Your photos, videos and projects stay on this device and are never uploaded. '
              'The app only goes online to download text fonts from Google Fonts.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open source licenses'),
            onTap: () => showLicensePage(context: context, applicationName: 'Canvo Edit', applicationVersion: appVersion),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Share problem log'),
            subtitle: const Text('Sends nothing unless you choose where to share it', style: TextStyle(color: AppColors.muted)),
            onTap: () => _shareLog(context),
          ),
        ],
      ),
    );
  }
}
