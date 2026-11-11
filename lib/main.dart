import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'core/crash_log.dart';
import 'features/home/home_screen.dart';
import 'features/settings/about_screen.dart';

const appLicenseNotice =
    'Copyright (C) 2026 Athlorun\n\n'
    'This program is free software: you can redistribute it and/or modify it under the terms of '
    'the GNU General Public License as published by the Free Software Foundation, either version 3 '
    'of the License, or (at your option) any later version.\n\n'
    'This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; '
    'without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. '
    'See the GNU General Public License for more details.\n\n'
    'Source code and the full license text: $sourceCodeUrl';

const ffmpegLicenseNotice =
    'This app includes FFmpeg (https://ffmpeg.org) and x264, built by FFmpegKit and licensed under '
    'the GNU General Public License version 3. FFmpeg is a trademark of Fabrice Bellard.';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    CrashLog.install();
    LicenseRegistry.addLicense(() async* {
      yield const LicenseEntryWithLineBreaks(['Canvo Edit'], appLicenseNotice);
      yield const LicenseEntryWithLineBreaks(['FFmpeg', 'x264'], ffmpegLicenseNotice);
    });
    runApp(const CanvoEditApp());
  }, CrashLog.record);
}

class CanvoEditApp extends StatelessWidget {
  const CanvoEditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Canvo Edit', debugShowCheckedModeBanner: false, theme: buildTheme(), home: const HomeScreen());
  }
}
