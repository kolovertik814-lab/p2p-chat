import 'package:flutter/material.dart';

void main() {
  runApp(const TelegramP2PApp());
}

class TelegramP2PApp extends StatelessWidget {
  const TelegramP2PApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P2P Messenger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1D2733),
        primaryColor: const Color(0xFF2AABEE),
      ),
      home: const MainChatScreen(),
    );
  }
}

class MessageModel {
  final String text;
  final bool isMe;

  MessageModel({required this.text, required this.isMe});
}

class MainChatScreen extends StatefulWidget {
  const MainChatScreen({super.key});

  @override
  State<MainChatScreen> createState() => _MainChatScreenState();
}

class _MainChatScreenState extends State<MainChatScreen> {
  final List<MessageModel> _messages = [];
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  void _sendTextMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(MessageModel(text: text, isMe: true));
      _msgController.clear();
    });
  }

  void _connectToPeerByTag(String tag) {
    if (tag.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Подключение к улу @$tag...')),
    );
  }

  @override
  void dispose() {
    _msgController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF212D3B),
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Поиск по @логину...',
              prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              fillColor: const Color(0xFF18222D),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: _connectToPeerByTag,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: msg.isMe ? const Color(0xFF2B5278) : const Color(0xFF182533),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg.text,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: const Color(0xFF212D3B),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(
                      hintText: 'Сообщение',
                      border: InputBorder.none,
                    ),
                  ),
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
}
