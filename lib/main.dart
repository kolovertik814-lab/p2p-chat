import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const P2PChatApp());
}

class P2PChatApp extends StatelessWidget {
  const P2PChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P2P Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const AuthCheckScreen(),
    );
  }
}

// ==================== ПРОВЕРКА АВТОРИЗАЦИИ ====================
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkSavedUser();
  }

  Future<void> _checkSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('my_nickname');

    if (!mounted) return;

    if (savedName != null && savedName.trim().isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainChatScreen(nickname: savedName)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ==================== ЭКРАН ВХОДА ====================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();

  Future<void> _saveAndEnter() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_nickname', name);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MainChatScreen(nickname: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход в P2P Чат')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_circle, size: 80, color: Colors.indigo),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Введите ваш никнейм',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveAndEnter,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Войти', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== МОДЕЛЬ СООБЩЕНИЯ ====================
class ChatMessage {
  final String sender;
  final String? text;
  final String? imagePath;
  final bool isMe;
  final DateTime timestamp;

  ChatMessage({
    required this.sender,
    this.text,
    this.imagePath,
    required this.isMe,
    required this.timestamp,
  });
}

// ==================== ГЛАВНЫЙ ЭКРАН ЧАТА ====================
class MainChatScreen extends StatefulWidget {
  final String nickname;
  const MainChatScreen({super.key, required this.nickname});

  @override
  State<MainChatScreen> createState() => _MainChatScreenState();
}

class _MainChatScreenState extends State<MainChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();

  ServerSocket? _serverSocket;
  Socket? _clientSocket;
  String _localIp = 'Загрузка IP...';
  bool _isConnected = false;
  final ImagePicker _picker = ImagePicker();

  static const int port = 4545;

  @override
  void initState() {
    super.initState();
    _initNetwork();
  }

  @override
  void dispose() {
    _serverSocket?.close();
    _clientSocket?.close();
    _msgController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  // --- ИНИЦИАЛИЗА СЕТИ ---
  Future<void> _initNetwork() async {
    // Получаем локальный IP
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            setState(() {
              _localIp = addr.address;
            });
            break;
          }
        }
      }
    } catch (e) {
      setState(() {
        _localIp = 'Ошибка получения IP';
      });
    }

    // Запускаем TCP Сервер для приема входящих подключений
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _serverSocket!.listen((Socket socket) {
        _handleIncomingConnection(socket);
      });
    } catch (e) {
      debugPrint('Ошибка запуска сервера: $e');
    }
  }

  void _handleIncomingConnection(Socket socket) {
    _clientSocket = socket;
    setState(() {
      _isConnected = true;
    });

    utf8.decoder.bind(socket).transform(const LineSplitter()).listen(
      (data) => _processReceivedData(data),
      onDone: () {
        setState(() {
          _isConnected = false;
        });
      },
      onError: (e) {
        setState(() {
          _isConnected = false;
        });
      },
    );
  }

  // --- ПОДКЛЮЧЕНИЕ К ДРУГОМУ УСТРОЙСТВУ ---
  Future<void> _connectToPeer() async {
    final targetIp = _ipController.text.trim();
    if (targetIp.isEmpty) return;

    try {
      final socket = await Socket.connect(targetIp, port, timeout: const Duration(seconds: 5));
      _handleIncomingConnection(socket);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Успешно подключено к $targetIp')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось подключиться: $e')),
        );
      }
    }
  }

  // --- ОБРАБОТКА ПОЛУЧЕННЫХ ДАННЫХ ---
  Future<void> _processReceivedData(String rawData) async {
    try {
      final json = jsonDecode(rawData);
      final sender = json['sender'] ?? 'Неизвестный';
      final type = json['type'];

      if (type == 'text') {
        setState(() {
          _messages.add(ChatMessage(
            sender: sender,
            text: json['text'],
            isMe: false,
            timestamp: DateTime.now(),
          ));
        });
      } else if (type == 'image') {
        final base64Image = json['data'];
        final bytes = base64Decode(base64Image);

        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(bytes);

        setState(() {
          _messages.add(ChatMessage(
            sender: sender,
            imagePath: file.path,
            isMe: false,
            timestamp: DateTime.now(),
          ));
        });
      }
    } catch (e) {
      debugPrint('Ошибка разбора сообщения: $e');
    }
  }

  // --- ОТПРАВКА ТЕКСТА ---
  void _sendTextMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final payload = {
      'type': 'text',
      'sender': widget.nickname,
      'text': text,
    };

    _sendPayload(payload);

    setState(() {
      _messages.add(ChatMessage(
        sender: widget.nickname,
        text: text,
        isMe: true,
        timestamp: DateTime.now(),
      ));
    });

    _msgController.clear();
  }

  // --- ОТПРАВКА КАРТИНКИ ---
  Future<void> _pickAndSendImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    final bytes = await File(image.path).readAsBytes();
    final base64Image = base64Encode(bytes);

    final payload = {
      'type': 'image',
      'sender': widget.nickname,
      'data': base64Image,
    };

    _sendPayload(payload);

    setState(() {
      _messages.add(ChatMessage(
        sender: widget.nickname,
        imagePath: image.path,
        isMe: true,
        timestamp: DateTime.now(),
      ));
    });
  }

  void _sendPayload(Map<String, dynamic> payload) {
    if (_clientSocket != null && _isConnected) {
      _clientSocket!.write(jsonEncode(payload) + '\n');
    }
  }

  // --- ВЫХОД ИЗ АККАУНТА ---
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('my_nickname');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Привет, ${widget.nickname}'),
            Text('Мой IP: $_localIp', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Выйти',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Панель подключения к собеседнику
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: _isConnected ? Colors.green.shade50 : Colors.red.shade50,
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.check_circle : Icons.error_outline,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _isConnected
                      ? const Text('Соединено с собеседником', style: TextStyle(fontWeight: FontWeight.bold))
                      : TextField(
                          controller: _ipController,
                          decoration: const InputDecoration(
                            hintText: 'IP второго устройства',
                            isDense: true,
                          ),
                        ),
                ),
                if (!_isConnected)
                  ElevatedButton(
                    onPressed: _connectToPeer,
                    child: const Text('Соединить'),
                  ),
              ],
            ),
          ),
          // Список сообщений
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),
          // Панель ввода и отправки
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.indigo),
                  onPressed: _pickAndSendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(
                      hintText: 'Сообщение...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.indigo),
                  onPressed: _sendTextMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.vertical(4),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: msg.isMe ? Colors.indigo.shade100 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.sender,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            if (msg.text != null)
              Text(msg.text!, style: const TextStyle(fontSize: 16)),
            if (msg.imagePath != null)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullScreenImageScreen(imagePath: msg.imagePath!),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(msg.imagePath!),
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== ПРОСМОТР ФОТО ВО ВЕСЬ ЭКРАН С ЗУМОМ ====================
class FullScreenImageScreen extends StatelessWidget {
  final String imagePath;
  const FullScreenImageScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(File(imagePath)),
        ),
      ),
    );
  }
}
