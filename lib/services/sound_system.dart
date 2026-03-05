import 'package:audioplayers/audioplayers.dart';

/// Central sound feedback for success, error, and button clicks across the app
/// (e.g. User Management, Entity Management, Module Access).
class SoundSystem {
  SoundSystem._();

  static final AudioPlayer _player = AudioPlayer();

  static const String _successAsset = 'sounds/Successful_1.wav';
  static const String _errorAsset = 'sounds/error_1.wav';
  static const String _buttonClickAsset = 'sounds/clapass.wav';
  static const String _loginPassAsset = 'sounds/LoginPass.wav';

  /// Call once when the user has landed inside the app after successful manual login.
  static void playLoginSuccess() {
    _play(_loginPassAsset);
  }

  /// Call when an update or operation succeeds (e.g. user/entity/module access updated).
  static void playSuccess() {
    _play(_successAsset);
  }

  /// Call when an operation fails or an error is shown to the user.
  static void playError() {
    _play(_errorAsset);
  }

  /// Call when a button is clicked (use on the specific buttons you want click feedback on).
  static void playButtonClick() {
    _play(_buttonClickAsset);
  }

  static void _play(String assetPath) {
    _player.play(AssetSource(assetPath)).catchError((Object e) {
      assert(false, 'SoundSystem: failed to play $assetPath: $e');
    });
  }
}
