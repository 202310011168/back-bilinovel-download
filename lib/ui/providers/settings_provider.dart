import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

class SettingsProvider extends ChangeNotifier {
  // ─── Theme ───
  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = const Color(0xFFC62828);
  bool _useDynamicColor = false;

  // ─── Safe Area ───
  bool _safeAreaEnabled = true;

  // ─── Output Directory ───
  String? _outputDirectory;

  // ─── Book Naming ───
  bool _useNumericId = false;

  // ─── Background ───
  String? _backgroundPath;
  double _backgroundOpacity = 0.3;
  int _backgroundFit = 0; // 0=cover, 1=repeat, 2=fill
  Color? _extractedColor;

  // ─── Gesture Lock ───
  bool _gestureEnabled = false;
  String? _gestureHash;
  String? _pinHash;

  // ─── Getters ───
  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  bool get useDynamicColor => _useDynamicColor;
  bool get safeAreaEnabled => _safeAreaEnabled;
  String? get outputDirectory => _outputDirectory;
  bool get useNumericId => _useNumericId;
  String? get backgroundPath => _backgroundPath;
  double get backgroundOpacity => _backgroundOpacity;
  int get backgroundFit => _backgroundFit;
  Color? get extractedColor => _extractedColor;
  bool get gestureEnabled => _gestureEnabled;
  bool get hasGesture => _gestureHash != null;
  bool get hasPin => _pinHash != null;
  String? get gestureHash => _gestureHash;
  String? get pinHash => _pinHash;

  static const String _kThemeMode = 'theme_mode';
  static const String _kAccentColor = 'accent_color';
  static const String _kDynamicColor = 'use_dynamic_color';
  static const String _kSafeArea = 'safe_area_enabled';
  static const String _kOutputDir = 'output_directory';
  static const String _kNumericId = 'use_numeric_id';
  static const String _kBgPath = 'background_path';
  static const String _kBgOpacity = 'background_opacity';
  static const String _kBgFit = 'background_fit';
  static const String _kGestureEnabled = 'gesture_enabled';
  static const String _kGestureHash = 'gesture_hash';
  static const String _kPinHash = 'pin_hash';

  static const List<Color> presetColors = [
    Color(0xFF1E293B), // 石板灰 (default)
    Color(0xFF1565C0), // 靛蓝
    Color(0xFF0D47A1), // 深蓝
    Color(0xFF00838F), // 青色
    Color(0xFF2E7D32), // 翠绿
    Color(0xFF558B2F), // 石灰
    Color(0xFFE65100), // 橙色
    Color(0xFFFF8F00), // 琥珀
    Color(0xFFC62828), // 深红
    Color(0xFF6A1B9A), // 紫罗兰
    Color(0xFFAD1457), // 粉色
    Color(0xFF4E342E), // 棕色
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[prefs.getInt(_kThemeMode) ?? 0]; // 0 = system
    _accentColor = Color(prefs.getInt(_kAccentColor) ?? 0xFFC62828);
    _useDynamicColor = prefs.getBool(_kDynamicColor) ?? false;
    _safeAreaEnabled = prefs.getBool(_kSafeArea) ?? true;
    _outputDirectory = prefs.getString(_kOutputDir);
    _useNumericId = prefs.getBool(_kNumericId) ?? false;
    _backgroundPath = prefs.getString(_kBgPath);
    _backgroundOpacity = prefs.getDouble(_kBgOpacity) ?? 0.3;
    _backgroundFit = prefs.getInt(_kBgFit) ?? 0;
    _gestureEnabled = prefs.getBool(_kGestureEnabled) ?? false;
    _gestureHash = prefs.getString(_kGestureHash);
    _pinHash = prefs.getString(_kPinHash);
    notifyListeners();
  }

  // ─── Theme ───

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveInt(_kThemeMode, mode.index);
    notifyListeners();
  }

  void setAccentColor(Color color) {
    _accentColor = color;
    _saveInt(_kAccentColor, color.toARGB32());
    notifyListeners();
  }

  void setUseDynamicColor(bool v) {
    _useDynamicColor = v;
    _saveBool(_kDynamicColor, v);
    notifyListeners();
  }

  // ─── Output Directory ───

  void setOutputDirectory(String? path) {
    _outputDirectory = path;
    if (path != null) {
      _saveString(_kOutputDir, path);
    } else {
      SharedPreferences.getInstance().then((p) => p.remove(_kOutputDir));
    }
    notifyListeners();
  }

  // ─── Safe Area ───

  void setSafeAreaEnabled(bool v) {
    _safeAreaEnabled = v;
    _saveBool(_kSafeArea, v);
    notifyListeners();
  }

  // ─── Book Naming ───

  void setUseNumericId(bool v) {
    _useNumericId = v;
    _saveBool(_kNumericId, v);
    notifyListeners();
  }

  // ─── Background ───

  void setBackgroundPath(String? path) {
    _backgroundPath = path;
    if (path != null) {
      _saveString(_kBgPath, path);
    } else {
      SharedPreferences.getInstance().then((p) => p.remove(_kBgPath));
    }
    notifyListeners();
  }

  void setBackgroundOpacity(double v) {
    _backgroundOpacity = v;
    _saveDouble(_kBgOpacity, v);
    notifyListeners();
  }

  void setBackgroundFit(int v) {
    _backgroundFit = v;
    _saveInt(_kBgFit, v);
    notifyListeners();
  }

  void setExtractedColor(Color? c) {
    _extractedColor = c;
    notifyListeners();
  }

  // ─── Gesture Lock ───

  void setGestureEnabled(bool v) {
    _gestureEnabled = v;
    _saveBool(_kGestureEnabled, v);
    notifyListeners();
  }

  bool verifyGesture(String pattern) {
    if (_gestureHash == null) return false;
    return _hash(pattern) == _gestureHash;
  }

  void setGesture(String pattern) {
    _gestureHash = _hash(pattern);
    _saveString(_kGestureHash, _gestureHash!);
  }

  bool verifyPin(String pin) {
    if (_pinHash == null) return false;
    return _hash(pin) == _pinHash;
  }

  void setPin(String pin) {
    _pinHash = _hash(pin);
    _saveString(_kPinHash, _pinHash!);
  }

  void clearGesture() {
    _gestureHash = null;
    _pinHash = null;
    _gestureEnabled = false;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_kGestureHash);
      prefs.remove(_kPinHash);
      prefs.remove(_kGestureEnabled);
    });
    notifyListeners();
  }

  // ─── Theme Build ───

  ThemeData buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _accentColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF8F9FA)
          : const Color(0xFF121212),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 0.5,
        space: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ─── Persistence ───

  void _saveInt(String key, int value) {
    SharedPreferences.getInstance().then((p) => p.setInt(key, value));
  }

  void _saveDouble(String key, double value) {
    SharedPreferences.getInstance().then((p) => p.setDouble(key, value));
  }

  void _saveBool(String key, bool value) {
    SharedPreferences.getInstance().then((p) => p.setBool(key, value));
  }

  void _saveString(String key, String value) {
    SharedPreferences.getInstance().then((p) => p.setString(key, value));
  }

  static String _hash(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}
