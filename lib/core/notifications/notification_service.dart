import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  // 1. Instancja pluginu (To naprawia błąd "Undefined name")
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Inicjalizacja (wywoływana w main.dart)
  Future<void> init() async {
    // Ustawienia dla Androida (ikona aplikacji)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Ustawienia dla iOS (podstawowe uprawnienia)
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Połączenie ustawień
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // Inicjalizacja pluginu
    await _notificationsPlugin.initialize(settings: initializationSettings);
  }

  // Metoda do wysyłania powiadomienia
  Future<void> showLowStockNotification(String itemName, int quantity) async {
    // Konfiguracja kanału powiadomień dla Androida
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        const AndroidNotificationDetails(
      'low_stock_channel', // ID kanału (unikalne)
      'Low Stock Alerts', // Nazwa widoczna dla usera
      channelDescription: 'Notifications for items running low',
      importance: Importance.max,
      priority: Priority.high,
      // Naprawiony kolor (używamy klasy Color, nie int)
      color: Color(0xFFFF0000),
    );

    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // WYSYŁANIE POWIADOMIENIA
    // UWAGA: W nowych wersjach biblioteki parametry MUSZĄ być nazwane (id:, title:, body:)
    await _notificationsPlugin.show(
      id: 0, // ID powiadomienia
      title: 'Low Stock Alert! ⚠️', // Tytuł
      body: '$itemName is running low ($quantity left). Reorder soon!', // Treść
      notificationDetails: platformChannelSpecifics, // Konfiguracja
    );
  }
}
