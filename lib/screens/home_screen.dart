import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

// --- VARIABLES GLOBALES DINÁMICAS ---
String targetUrl = "https://www.carrefour.es/gaming"; // URL por defecto
List<String> stockKeywords = ["PlayStation 5"];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      initialNotificationTitle: 'Monitor de Stock Activo',
      initialNotificationContent: 'Vigilando la web configurada...',
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

  Timer.periodic(const Duration(minutes: 10), (timer) async {
    try {
      final response = await http.get(Uri.parse(targetUrl));
      if (response.statusCode == 200) {
        final html = response.body.toLowerCase();
        for (final word in stockKeywords) {
          final cleanWord = word.trim().toLowerCase();
          if (cleanWord.isNotEmpty && html.contains(cleanWord)) {
            BackgroundNotificationHelper.showSilentNotification(word);
            break; // Solo una notificación por ciclo
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
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.orange),
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
  
  // Controladores para los campos de texto
  final TextEditingController _urlController = TextEditingController(text: targetUrl);
  final TextEditingController _keywordController = TextEditingController();
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

  void _updateUrl() {
    setState(() {
      targetUrl = _urlController.text.trim();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URL de búsqueda actualizada')),
    );
  }

  void _addKeyword() {
    if (_keywordController.text.trim().isNotEmpty) {
      setState(() {
        stockKeywords.add(_keywordController.text.trim());
        _keywordController.clear();
      });
    }
  }

  Future<void> _checkStock() async {
    if (targetUrl.isEmpty || !targetUrl.startsWith("http")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce una URL válida (http/https)')),
      );
      return;
    }

    setState(() => stockStatus = 'Analizando web...');

    try {
      final response = await http.get(Uri.parse(targetUrl));
      String? foundWord;

      if (response.statusCode == 200) {
        final html = response.body.toLowerCase();
        for (final word in stockKeywords) {
          final cleanWord = word.trim().toLowerCase();
          if (cleanWord.isNotEmpty && html.contains(cleanWord)) {
            foundWord = word;
            break;
          }
        }
      }

      if (foundWord != null) {
        await _playAlarm();
        await _showNotification(foundWord);
        setState(() {
          hasStock = true;
          stockStatus = '✅ ¡STOCK: $foundWord!';
        });
      } else {
        setState(() {
          hasStock = false;
          stockStatus = '❌ Sin stock en esta URL';
        });
      }
      setState(() => lastCheck = _getFormattedTime());
    } catch (e) {
      setState(() {
        stockStatus = '⚠️ Error: No se pudo cargar la web';
        hasStock = false;
        lastCheck = _getFormattedTime();
      });
    }
  }

  String _getFormattedTime() => "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";

  Future<void> _playAlarm() async {
    final player = AudioPlayer();
    await player.play(AssetSource('alarma.mp3'), volume: 1.0);
  }

  Future<void> _showNotification(String keyword) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'stock_channel', 'Alertas de Stock', importance: Importance.max, priority: Priority.high,
    );
    await notificationsPlugin.show(1, '🎮 Stock detectado', 'Encontrado en la web: $keyword', const NotificationDetails(android: androidDetails));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Monitor Pro 🚀'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panel de Estado
            Center(
              child: Column(
                children: [
                  Icon(hasStock ? Icons.check_circle : Icons.radar, size: 70, color: hasStock ? Colors.green : Colors.orange),
                  const SizedBox(height: 10),
                  Text(stockStatus, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: hasStock ? Colors.green : Colors.red)),
                  Text('Último intento: $lastCheck', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const Divider(height: 40),

            // Campo de URL
            const Text('1. URL de la tienda', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _urlController,
              onChanged: (val) => targetUrl = val.trim(),
              decoration: InputDecoration(
                hintText: 'https://...',
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: const Icon(Icons.save), onPressed: _updateUrl),
              ),
            ),
            const SizedBox(height: 25),

            // Campo de Palabras Clave
            const Text('2. Palabras clave (ej: PS5, Stock...)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keywordController,
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Nueva palabra...'),
                    onSubmitted: (_) => _addKeyword(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(onPressed: _addKeyword, icon: const Icon(Icons.add)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: stockKeywords.map((word) => Chip(
                label: Text(word),
                onDeleted: () => setState(() => stockKeywords.remove(word)),
              )).toList(),
            ),
            
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _checkStock,
                icon: const Icon(Icons.search),
                label: const Text('FORZAR COMPROBACIÓN'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BackgroundNotificationHelper {
  static void showSilentNotification(String word) async {
    final FlutterLocalNotificationsPlugin flip = FlutterLocalNotificationsPlugin();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'stock_channel', 'Alertas de Stock', importance: Importance.max, priority: Priority.high,
    );
    await flip.show(2, '🎮 ¡STOCK DISPONIBLE!', 'Se encontró "$word" en la web configurada', const NotificationDetails(android: androidDetails));
  }
}