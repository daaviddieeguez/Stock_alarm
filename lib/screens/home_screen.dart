import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

// --- VARIABLES GLOBALES DINÁMICAS ---
String targetUrl = "https://www.carrefour.es/gaming";
List<String> stockKeywords = ["PlayStation 5"];
const int checkIntervalMinutes = 10; // Intervalo centralizado

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
      initialNotificationContent: 'Vigilando cada $checkIntervalMinutes min...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
  service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  String currentUrl = targetUrl;
  List<String> currentKeywords = List.from(stockKeywords);

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  service.on("updateConfig").listen((event) {
    if (event != null) {
      currentUrl = event["url"];
      currentKeywords = List<String>.from(event["keywords"]);
    }
  });

  Timer.periodic(const Duration(minutes: checkIntervalMinutes), (timer) async {
    try {
      final response = await http.get(Uri.parse(currentUrl));
      if (response.statusCode == 200) {
        final html = response.body.toLowerCase();
        for (final word in currentKeywords) {
          if (html.contains(word.toLowerCase().trim())) {
            BackgroundNotificationHelper.showSilentNotification(word);
            break; 
          }
        }
      }
    } catch (e) { debugPrint("Error background: $e"); }
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
  
  // Lógica de Cuenta Atrás
  Timer? _countdownTimer;
  int _secondsRemaining = checkIntervalMinutes * 60;

  final TextEditingController _urlController = TextEditingController(text: targetUrl);
  final TextEditingController _keywordController = TextEditingController();
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _startCountdown(); // Iniciar reloj al abrir
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _urlController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _secondsRemaining = checkIntervalMinutes * 60;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _checkStock(); // Autocomprobar al llegar a cero en la UI
        }
      });
    });
  }

  String _formatDuration(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  Future<void> _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notificationsPlugin.initialize(const InitializationSettings(android: androidInit));
  }

  void _syncWithService() {
    FlutterBackgroundService().invoke("updateConfig", {
      "url": targetUrl,
      "keywords": stockKeywords,
    });
  }

  void _updateUrl() {
    setState(() => targetUrl = _urlController.text.trim());
    _syncWithService();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL sincronizada')));
  }

  void _addKeyword() {
    if (_keywordController.text.trim().isNotEmpty) {
      setState(() {
        stockKeywords.add(_keywordController.text.trim());
        _keywordController.clear();
      });
      _syncWithService();
    }
  }

  Future<void> _checkStock() async {
    _startCountdown(); // Reiniciar el reloj siempre que se comprueba
    
    if (targetUrl.isEmpty || !targetUrl.startsWith("http")) return;

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
          stockStatus = '❌ Sin stock';
        });
      }
      setState(() => lastCheck = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}");
    } catch (e) {
      setState(() {
        stockStatus = '⚠️ Error de conexión';
        hasStock = false;
      });
    }
  }

  Future<void> _playAlarm() async {
    final player = AudioPlayer();
    await player.play(AssetSource('alarma.mp3'), volume: 1.0);
  }

  Future<void> _showNotification(String keyword) async {
    const androidDetails = AndroidNotificationDetails('stock_channel', 'Alertas de Stock', importance: Importance.max, priority: Priority.high);
    await notificationsPlugin.show(1, '🎮 Stock detectado', 'Encontrado: $keyword', const NotificationDetails(android: androidDetails));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Monitor Pro 🚀'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // PANEL DE CUENTA ATRÁS
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text("Siguiente comprobación en:", style: TextStyle(fontSize: 14, color: Colors.grey)),
                  Text(
                    _formatDuration(_secondsRemaining),
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.orange),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history, size: 16, color: Colors.grey),
                      const SizedBox(width: 5),
                      Text("Última: $lastCheck", style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(stockStatus, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: hasStock ? Colors.green : Colors.red)),
            const Divider(height: 40),

            // CONFIGURACIÓN
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL de la tienda',
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: const Icon(Icons.save), onPressed: _updateUrl),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keywordController,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Añadir palabra clave'),
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
                onDeleted: () {
                  setState(() => stockKeywords.remove(word));
                  _syncWithService();
                },
              )).toList(),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _checkStock,
                icon: const Icon(Icons.search),
                label: const Text('COMPROBAR AHORA'),
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
    final flip = FlutterLocalNotificationsPlugin();
    const androidDetails = AndroidNotificationDetails('stock_channel', 'Alertas de Stock', importance: Importance.max, priority: Priority.high);
    await flip.show(2, '🎮 ¡STOCK DISPONIBLE!', 'Se encontró "$word"', const NotificationDetails(android: androidDetails));
  }
}