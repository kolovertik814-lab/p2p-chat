import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

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
  final String type; // 'text', 'image', 'audio'
  final Uint8List? bytes;

  MessageModel({
    required this.text,
    required this.isMe,
    this.type = 'text',
    this.bytes,
  });
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
  
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  final Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  @override
  void initState() {
    super.initState();
    _initP2P();
  }

  Future<void> _initP2P() async {
    _peerConnection = await createPeerConnection(_rtcConfig);

    RTCDataChannelInit init = RTCDataChannelInit()..binaryType = 'binary';
    _dataChannel = await _peerConnection!.createDataChannel('chat_channel', init);

    _dataChannel!.onMessage = (RTCDataChannelMessage data) {
      if (data.isBinary) {
        setState(() {
          _messages.add(MessageModel(
            text: 'Получено фото',
            isMe: false,
            type: 'image',
            bytes: data.binary,
          ));
        });
      } else {
        setState(() {
          _messages.add(MessageModel(text: data.text, isMe: false));
        });
      }
    };
  }

  void _connectToPeerByTag(String tag) {
    if (tag.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Поиск узла для $tag...')),
    );
  }

  void _sendTextMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    if (_dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(RTCDataChannelMessage(text));
    }

    setState(() {
      _messages.add(MessageModel(text: text, isMe: true));
      _msgController.clear();
    });
  }

  Future<void> _pickAndSendImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      Uint8List fileBytes = result.files.single.bytes!;
      
      if (_dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
        _dataChannel!.send(RTCDataChannelMessage.fromBinary(fileBytes));
      }

      setState(() {
        _messages.add(MessageModel(
          text: 'Фотография',
          isMe: true,
          type: 'image',
          bytes: fileBytes,
        ));
      });
    }
  }

  Future<void> _toggleAudioRecord() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        setState(() {
          _messages.add(MessageModel(text: 'Голосовое сообщение', isMe: true, type: 'audio'));
        });
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        await _audioRecorder.start(
          const RecordConfig(),
          path: '${dir.path}/gs_${DateTime.now().millisecondsSinceEpoch}.m4a',
        );
        setState(() {
          _isRecording = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _peerConnection?.close();
    _dataChannel?.close();
    _audioRecorder.dispose();
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
                    child: msg.type == 'image' && msg.bytes != null
                        ? Image.memory(msg.bytes!, width: 200)
                        : Text(
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
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.grey),
                  onPressed: _pickAndSendImage,
                ),
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
                  icon: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: _isRecording ? Colors.red : Colors.grey,
                  ),
                  onPressed: _toggleAudioRecord,
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