import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyByokApiKey = 'voicepen_byok_api_key';
  static const String _keyIsProUser = 'voicepen_is_pro_user';
  static const String _keyDefaultTone = 'voicepen_default_tone';
  static const String _keyCustomTonePrompt = 'voicepen_custom_tone_prompt';
  static const String _keyAudioCloudBackup = 'voicepen_audio_cloud_backup';

  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static Future<PreferencesService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  String getCustomTonePrompt() {
    return _prefs.getString(_keyCustomTonePrompt) ?? '';
  }

  Future<bool> setCustomTonePrompt(String prompt) async {
    return await _prefs.setString(_keyCustomTonePrompt, prompt.trim());
  }

  String getByokApiKey() {
    return _prefs.getString(_keyByokApiKey) ?? '';
  }

  Future<bool> setByokApiKey(String key) async {
    return await _prefs.setString(_keyByokApiKey, key.trim());
  }

  bool isProUser() {
    return _prefs.getBool(_keyIsProUser) ?? false;
  }

  Future<bool> setProUser(bool isPro) async {
    return await _prefs.setBool(_keyIsProUser, isPro);
  }

  String getDefaultTone() {
    return _prefs.getString(_keyDefaultTone) ?? 'Clear & Concise';
  }

  Future<bool> setDefaultTone(String tone) async {
    return await _prefs.setString(_keyDefaultTone, tone);
  }

  bool isAudioCloudBackupEnabled() {
    return _prefs.getBool(_keyAudioCloudBackup) ?? false;
  }

  Future<bool> setAudioCloudBackupEnabled(bool enabled) async {
    return await _prefs.setBool(_keyAudioCloudBackup, enabled);
  }
}
