import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String lastCheck = 'Nunca';

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final List<String> keywords = [
    "PlayStation 5",
    "PlayStation 5 Slim",
    "PlayStation 5 Digital Slim",
    "Xbox Series S"
  ];

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);
    await notificationsPlugin.initialize(initSettings);
  }

  Future<void> _checkStock() async {
    const url = "https://www.carrefour.es/gaming"; // Cambia a tu URL
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final html = response.body;
        for (final word in keywords) {
          if (html.contains(word)) {
            await _playAlarm();
            await _showNotification(word);
            break;
          }
        }
      }
      setState(() {
        lastCheck = DateTime.now().toString();
      });
    } catch (e) {
      setState(() {
        lastCheck = 'Error al comprobar';
      });
    }
  }

  Future<void> _playAlarm() async {
    final player = AudioPlayer();
    await player.play(AssetSource('alarma.mp3'), volume: 1.0);
  }

  Future<void> _showNotification(String keyword) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'stock_channel',
      'Monitor de Stock',
      channelDescription: 'Notificaciones cuando se detecta stock',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const NotificationDetails details =
        NotificationDetails(android: androidDetails);
    await notificationsPlugin.show(
      0,
      '🎮 Stock detectado',
      'Se encontró: $keyword',
      details,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.radar, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'Monitor activo en segundo plano',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'El servicio revisará el stock automáticamente cada 10 minutos.',
                textAlign: TextAlign.center,
              ),
            ),
            ElevatedButton(
              onPressed: _checkStock,
              child: const Text('Comprobar stock ahora'),
            ),
            const SizedBox(height: 10),
            Text('Última comprobación: $lastCheck'),
          ],
        ),
      ),
    );
  }
}
