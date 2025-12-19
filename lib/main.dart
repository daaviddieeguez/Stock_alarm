import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'screens/screens.dart';

// --- Configuración Global ---
const List<String> keywords = ['disponible', 'stock', 'añadir al carrito'];
const String targetUrl = "https://TU_URL_AQUI";

// 🚀 Inicialización del servicio
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // initNotifications();
  // initializeService();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

// ⚙️ Servicio en segundo plano
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      // Se eliminan notificationTitle y notificationText de aquí
      // Ahora se gestionan mediante el ID del canal o el plugin de notificaciones
      notificationChannelId: 'my_foreground', // ID opcional
      initialNotificationTitle: 'Monitor de Stock',
      initialNotificationContent: 'Buscando consolas...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
    ),
  );

  service.startService();
}

// 🧠 Lógica principal
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Temporizador de ejecución cada 10 minutos
  Timer.periodic(const Duration(minutes: 10), (timer) async {
    try {
      final response = await http.get(Uri.parse(targetUrl));

      if (response.statusCode == 200) {
        final html = response.body.toLowerCase();

        for (final word in keywords) {
          if (html.contains(word.toLowerCase())) {
            await playAlarm();
            break;
          }
        }
      }
    } catch (e) {
      debugPrint("Error en la petición: $e");
      // Errores ignorados para mantener el servicio vivo
    }
  });
}

// 🔔 Reproducir alarma
Future<void> playAlarm() async {
  final player = AudioPlayer();
  // Asegúrate de tener 'alarm.mp3' en tu carpeta assets y en pubspec.yaml
  await player.play(AssetSource('alarm.mp3'), volume: 1.0);
}