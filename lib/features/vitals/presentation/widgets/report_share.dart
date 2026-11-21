import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

/// Width of the shared image (logical px) — readable on any phone.
const reportImageWidth = 420.0;

/// Renders [report] off screen (whole, however long) into a PNG.
typedef ReportCapture = Future<Uint8List> Function(
  BuildContext context,
  Widget report,
);

/// Sends the PNG with a text summary (system share sheet).
typedef ReportShare = Future<void> Function(
  Uint8List png, {
  required String text,
  required String fileName,
  Rect? origin,
});

Future<Uint8List> captureReport(BuildContext context, Widget report) {
  final theme = Theme.of(context);
  final media = MediaQuery.of(context);
  final widget = Localizations.override(
    context: context,
    child: MediaQuery(
      data: media.copyWith(
        size: const Size(reportImageWidth, 2000),
        textScaler: TextScaler.noScaling,
        // Entrance animations (CascadeIn in cards and tiles) would be
        // caught at their first frame — transparent; show the end state.
        disableAnimations: true,
      ),
      child: Theme(
        data: theme,
        child: Material(
          color: theme.scaffoldBackgroundColor,
          child: SizedBox(width: reportImageWidth, child: report),
        ),
      ),
    ),
  );
  return ScreenshotController().captureFromLongWidget(
    widget,
    context: context,
    pixelRatio: 2.5,
    delay: const Duration(milliseconds: 100),
    constraints: const BoxConstraints(maxWidth: reportImageWidth),
  );
}

Future<void> shareReport(
  Uint8List png, {
  required String text,
  required String fileName,
  Rect? origin,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      files: [XFile.fromData(png, mimeType: 'image/png', name: fileName)],
      fileNameOverrides: [fileName],
      sharePositionOrigin: origin,
    ),
  );
}

final reportCaptureProvider = Provider<ReportCapture>((ref) => captureReport);

final reportShareProvider = Provider<ReportShare>((ref) => shareReport);
