import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the system pickers one at a time. Android rejects a second request
/// while a picker is open, which a quick double tap would otherwise trigger.
class MediaPicker {
  static final _picker = ImagePicker();
  static bool _open = false;

  /// Runs [pick] unless a picker is already open, in which case the request is
  /// ignored and the result is null. Real failures, such as a denied camera,
  /// go to [onError].
  static Future<T?> guard<T>(Future<T?> Function() pick, {required void Function(String) onError}) async {
    if (_open) return null;
    _open = true;
    try {
      return await pick();
    } on PlatformException catch (e) {
      if (e.code != 'already_active') onError(e.message ?? 'Could not open the picker');
      return null;
    } finally {
      _open = false;
    }
  }

  static Future<XFile?> image({required void Function(String) onError}) => guard(() => _picker.pickImage(source: ImageSource.gallery), onError: onError);

  static Future<List<XFile>> media({required void Function(String) onError}) async => await guard(_picker.pickMultipleMedia, onError: onError) ?? const [];

  static Future<XFile?> recordVideo({required void Function(String) onError}) => guard(() => _picker.pickVideo(source: ImageSource.camera), onError: onError);
}
