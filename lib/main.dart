import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const TelegramP2PApp());
}

class TelegramP2PApp extends StatelessWidget {
  const TelegramP2PApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telegram P2P',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1D2733),
        primaryColor: const Color(0xFF2AABEE),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF212D3B),
          elevation: 0,
        ),
      ),
      home: const AuthScreen(),
    );
  }
}

// --- Модели данных ---

enum MessageType { text, image, voice }

class ChatMessage {
  final String id;
  final String sender;
  final MessageType type;
  final String? text;
  final Uint8List? bytes;
  final String? path;
  final DateTime timestamp;
  final bool isMe;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.type,
    this.text,
    this.bytes,
    this.path,
    required this.timestamp,
    required this.isMe,
  });
}

class ChatItem {
  final String username;
  final String name;
  final List<ChatMessage> messages;

  ChatItem({
    required this.username,
    required this.name,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  String get lastMessageText {
    if (messages.isEmpty) return 'Нет сообщений';
    final last = messages.last;
    switch (last.type) {
      case MessageType.text:
        return last.text ?? '';
      case MessageType.image:
        return '📷 Фотография';
      case MessageType.voice:
        return '🎤 Голосовое сообщение';
    }
  }

  String get lastMessageTime {
    if (messages.isEmpty) return '';
    final last = messages.last;
    return '${last.timestamp.hour.toString().padLeft(2, '0')}:${last.timestamp.minute.toString().padLeft(2, '0')}';
  }
}

// --- Экран авторизации (придумывание логина) ---

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _usernameController = TextEditingController();

  void _login() {
    final username = _usernameController.text.trim().replaceAll('@', '');
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, введите ваш логин')),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(myUsername: username),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const ContainerLogo(),
              const SizedBox(height: 24),
              const Text(
                'Добро пожаловать в P2P Чаты',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Придумайте себе уникальный логин для связи',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ваш @логин',
                  prefixText: '@ ',
                  prefixStyle: const TextStyle(color: Color(0xFF2AABEE), fontWeight: FontWeight.bold),
                  fillColor: const Color(0xFF18222D),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2AABEE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _login,
                  child: const Text('Войти и начать чат', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContainerLogo extends StatelessWidget {
  const ContainerLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: const BoxDecoration(
        color: Color(0xFF2AABEE),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.send_rounded, size: 48, color: Colors.white),
    );
  }
}

// --- Главный экран со списком чатов (Telegram style) ---

class HomeScreen extends StatefulWidget {
  final String myUsername;
  const HomeScreen({super.key, required this.myUsername});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<ChatItem> _chats = [];
  final TextEditingController _addChatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Демонстрационный начальный чат
    _chats.add(ChatItem(
      username: 'support_bot',
      name: 'Служба поддержки P2P',
      messages: [
        ChatMessage(
          id: '1',
          sender: 'support_bot',
          type: MessageType.text,
          text: 'Привет! Нажмите на иконку поиска/плюса вверху, чтобы добавить собеседника по его @логину.',
          timestamp: DateTime.now(),
          isMe: false,
        )
      ],
    ));
  }

  void _addNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF212D3B),
        title: const Text('Новый чат'),
        content: TextField(
          controller: _addChatController,
          decoration: InputDecoration(
            hintText: 'Введите @логин пользователя',
            prefixText: '@',
            fillColor: const Color(0xFF18222D),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2AABEE)),
            onPressed: () {
              final tag = _addChatController.text.trim().replaceAll('@', '');
              if (tag.isNotEmpty) {
                setState(() {
                  _chats.insert(
                    0,
                    ChatItem(username: tag, name: '@$tag'),
                  );
                });
                _addChatController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: _addNewChatDialog,
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1D2733),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF212D3B)),
              accountName: Text('@${widget.myUsername}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: const Text('P2P Сеть активна', style: TextStyle(color: Color(0xFF2AABEE))),
              currentAccountPicture: CircleAvatar(
                backgroundColor: const Color(0xFF2AABEE),
                child: Text(
                  widget.myUsername.isNotEmpty ? widget.myUsername[0].toUpperCase() : 'U',
                  style: const TextStyle(fontSize: 28, color: Colors.white),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text('Настройки профиля'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Сменить логин'),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: _chats.isEmpty
          ? const Center(
              child: Text(
                'У вас пока нет чатов.\nНажмите + чтобы добавить собеседника.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.separated(
              itemCount: _chats.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFF10171D)),
              itemBuilder: (context, index) {
                final chat = _chats[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF2B5278),
                    child: Text(
                      chat.name.replaceAll('@', '')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(chat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(chat.lastMessageTime, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  subtitle: Text(
                    chat.lastMessageText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatDetailScreen(
                          chat: chat,
                          myUsername: widget.myUsername,
                        ),
                      ),
                    );
                    setState(() {}); // Обновить список сообщений на главном экране
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2AABEE),
        onPressed: _addNewChatDialog,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }
}

// --- Экран конкретной переписки (Чат) ---

class ChatDetailScreen extends StatefulWidget {
  final ChatItem chat;
  final String myUsername;

  const ChatDetailScreen({super.key, required this.chat, required this.myUsername});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  String? _playingVoiceId;

  void _sendTextMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      widget.chat.messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: widget.myUsername,
          type: MessageType.text,
          text: text,
          timestamp: DateTime.now(),
          isMe: true,
        ),
      );
      _msgController.clear();
    });
  }

  Future<void> _pickAndSendImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        widget.chat.messages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: widget.myUsername,
            type: MessageType.image,
            bytes: result.files.single.bytes,
            timestamp: DateTime.now(),
            isMe: true,
          ),
        );
      });
    }
  }

  Future<void> _toggleRecordVoice() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        setState(() {
          widget.chat.messages.add(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sender: widget.myUsername,
              type: MessageType.voice,
              path: path,
              timestamp: DateTime.now(),
              isMe: true,
            ),
          );
        });
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(const RecordConfig(), path: '');
        setState(() {
          _isRecording = true;
        });
      }
    }
  }

  Future<void> _playVoice(String id, String? path) async {
    if (path == null) return;
    if (_playingVoiceId == id) {
      await _audioPlayer.stop();
      setState(() {
        _playingVoiceId = null;
      });
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() {
        _playingVoiceId = id;
      });
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _playingVoiceId = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF2B5278),
              child: Text(
                widget.chat.name.replaceAll('@', '')[0].toUpperCase(),
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.chat.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Text('в сети', style: TextStyle(fontSize: 12, color: Color(0xFF2AABEE))),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.chat.messages.length,
              itemBuilder: (context, index) {
                final msg = widget.chat.messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),
          Container(
            color: const Color(0xFF212D3B),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.grey),
                  onPressed: _pickAndSendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _isRecording ? 'Запись голосового...' : 'Сообщение',
                      hintStyle: TextStyle(color: _isRecording ? Colors.redAccent : Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: _isRecording ? Colors.redAccent : Colors.grey,
                  ),
                  onPressed: _toggleRecordVoice,
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF2AABEE)),
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
    final isMe = msg.isMe;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF2B5278) : const Color(0xFF182533),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (msg.type == MessageType.text)
              Text(
                msg.text ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            if (msg.type == MessageType.image && msg.bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(msg.bytes!),
              ),
            if (msg.type == MessageType.voice)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _playingVoiceId == msg.id ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: () => _playVoice(msg.id, msg.path),
                  ),
                  const Text('Голосовое сообщение', style: TextStyle(color: Colors.white)),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
