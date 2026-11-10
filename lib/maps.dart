import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n.dart';

/// 場所を Google マップで開く URL（アプリが入っていればアプリで開く）。
Uri googleMapsUrl(String place) =>
    Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': place});

/// 場所を Apple のマップで開く URL（iPhone の標準のマップ）。
Uri appleMapsUrl(String place) =>
    Uri.https('maps.apple.com', '/', {'q': place});

/// 場所を地図アプリで開く。iPhone では Google マップか Apple のマップかを選べる。
Future<void> openInMaps(BuildContext context, String place) async {
  final query = place.trim();
  if (query.isEmpty) return;
  final isApple =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  if (!isApple) {
    await launchUrl(googleMapsUrl(query), mode: LaunchMode.externalApplication);
    return;
  }
  final url = await showModalBottomSheet<Uri>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(query),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: Text(context.l10n.googleMaps),
            onTap: () => Navigator.pop(sheet, googleMapsUrl(query)),
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: Text(context.l10n.appleMaps),
            onTap: () => Navigator.pop(sheet, appleMapsUrl(query)),
          ),
        ],
      ),
    ),
  );
  if (url != null) await launchUrl(url, mode: LaunchMode.externalApplication);
}

/// 予定の編集画面などに置く「場所」の入力欄。右の地図ボタンで確認できる。
class LocationField extends StatelessWidget {
  const LocationField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: 200,
      decoration: InputDecoration(
        labelText: context.l10n.location,
        hintText: context.l10n.locationHint,
        prefixIcon: const Icon(Icons.place_outlined),
        border: const OutlineInputBorder(),
        suffixIcon: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => IconButton(
            tooltip: context.l10n.openInMaps,
            icon: const Icon(Icons.map_outlined),
            onPressed: controller.text.trim().isEmpty
                ? null
                : () => openInMaps(context, controller.text),
          ),
        ),
      ),
    );
  }
}
