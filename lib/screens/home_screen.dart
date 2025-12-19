import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

// --- CONFIGURACIÓN GLOBAL ---
const String targetUrl = "https://www.carrefour.es/gaming";
const List<String> stockKeywords = ["PlayStation 5"];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar notificaciones para el servicio
  await initializeService();
  
  runApp(const MyApp());
}

// ⚙️ SERVICIO EN SEGUNDO PLANO
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      initialNotificationTitle: 'Monitor de Stock',
      initialNotificationContent: 'El monitor está activo...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );

  service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  // Timer que corre cada 10 minutos en segundo plano
  Timer.periodic(const Duration(minutes: 10), (timer) async {
    try {
      final response = await http.get(Uri.parse(targetUrl));
      if (response.statusCode == 200) {
        final html = response.body;
        for (final word in stockKeywords) {
          if (html.contains(word)) {
            // Aquí puedes llamar a una función simplificada de alarma/notificación
            // que no dependa del contexto de la UI
            BackgroundNotificationHelper.showSilentNotification(word);
          }
        }
      }
    } catch (e) {
      debugPrint("Error en segundo plano: $e");
    }
  });
}

// 🖥️ UI PRINCIPAL
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String lastCheck = 'Nunca';
  String stockStatus = 'Esperando comprobación...';
  bool hasStock = false;

  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);
    await notificationsPlugin.initialize(initSettings);
  }

  Future<void> _checkStock() async {
    setState(() {
      stockStatus = 'Comprobando...';
    });

    try {
      final response = await http.get(Uri.parse(targetUrl));
      bool detected = false;
      String foundWord = "";

      if (response.statusCode == 200) {
        final html = response.body;
        for (final word in stockKeywords) {
          if (html.contains(word)) {
            detected = true;
            foundWord = word;
            break;
          }
        }
      }

      if (detected) {
        await _playAlarm();
        await _showNotification(foundWord);
      }

      setState(() {
        lastCheck = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";
        hasStock = detected;
        stockStatus = detected ? '✅ ¡HAY STOCK DISPONIBLE!' : '❌ Sin stock de momento';
      });
    } catch (e) {
      setState(() {
        lastCheck = 'Error';
        stockStatus = '⚠️ Error de conexión';
        hasStock = false;
      });
    }
  }

  Future<void> _playAlarm() async {
    final player = AudioPlayer();
    // Asegúrate de que el nombre sea exacto: alarma.mp3
    await player.play(AssetSource('alarma.mp3'), volume: 1.0);
  }

  Future<void> _showNotification(String keyword) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'stock_channel',
      'Alertas de Stock',
      importance: Importance.max,
      priority: Priority.high,
    );
    await notificationsPlugin.show(
      1,
      '🎮 Stock detectado',
      'Se encontró: $keyword',
      const NotificationDetails(android: androidDetails),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Alarm 🚀')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasStock ? Icons.check_circle : Icons.radar,
              size: 100,
              color: hasStock ? Colors.green : Colors.blue,
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: hasStock ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: hasStock ? Colors.green : Colors.red),
              ),
              child: Text(
                stockStatus,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: hasStock ? Colors.green : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Última comprobación: $lastCheck',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _checkStock,
              icon: const Icon(Icons.refresh),
              label: const Text('Comprobar ahora'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Clase auxiliar para notificaciones fuera de la UI
class BackgroundNotificationHelper {
  static void showSilentNotification(String word) async {
    final FlutterLocalNotificationsPlugin flip = FlutterLocalNotificationsPlugin();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'stock_channel', 'Alertas de Stock',
      importance: Importance.max, priority: Priority.high,
    );
    const NotificationDetails d = NotificationDetails(android: androidDetails);
    await flip.show(2, '🎮 ¡STOCK EN SEGUNDO PLANO!', 'Se detectó: $word', d);
  }
}