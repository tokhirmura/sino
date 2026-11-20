import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/prefs.dart';

/// Where a prescription photo comes from.
enum RxPhotoSource { camera, gallery }

/// Takes a prescription photo. Returns the local file path, `null` when the
/// user cancelled. Throws when the camera / gallery is unavailable.
abstract class RxPhotoPicker {
  Future<String?> pick(RxPhotoSource source);
}

class ImagePickerRxPhotoPicker implements RxPhotoPicker {
  final _picker = ImagePicker();

  @override
  Future<String?> pick(RxPhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == RxPhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    return file?.path;
  }
}

final rxPhotoPickerProvider = Provider<RxPhotoPicker>(
  (ref) => ImagePickerRxPhotoPicker(),
);

/// Prescription photos stay on the device (the `reservations` table has only
/// `rx_attached`): `reservation id → local file path` in SharedPreferences.
/// The picker's file may be cleaned up by the OS later — the UI then shows
/// a placeholder.
class RxPhotosNotifier extends Notifier<Map<String, String>> {
  static const key = 'pharmacy.rx_photos';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Map<String, String> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(key);
    if (raw == null) return const {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return const {};
    }
  }

  Future<void> save(String reservationId, String path) async {
    state = {...state, reservationId: path};
    await _prefs.setString(key, jsonEncode(state));
  }

  Future<void> remove(String reservationId) async {
    state = {...state}..remove(reservationId);
    await _prefs.setString(key, jsonEncode(state));
  }
}

final rxPhotosProvider =
    NotifierProvider<RxPhotosNotifier, Map<String, String>>(
      RxPhotosNotifier.new,
    );
