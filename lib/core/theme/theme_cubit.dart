import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system) {
    _loadTheme();
  }

  static const _themeKey = 'theme_mode';

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    if (savedTheme == 'light')
      emit(ThemeMode.light);
    else if (savedTheme == 'dark')
      emit(ThemeMode.dark);
    else
      emit(ThemeMode.system);
  }

  void updateTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.light)
      await prefs.setString(_themeKey, 'light');
    else if (mode == ThemeMode.dark)
      await prefs.setString(_themeKey, 'dark');
    else
      await prefs.remove(_themeKey);
    emit(mode);
  }
}
