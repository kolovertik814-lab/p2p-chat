import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const P2PChatApp());
}

class P2PChatApp extends StatelessWidget {
  const P2PChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P2P WebRTC Chat',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  List<String> messages = [];
  String connectionStatus = 'Не подключено';
  bool isHost = false;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  final Map<String, dynamic> rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  @override
  void dispose() {
    _peerConnection?.dispose();
    _msgController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    setState(() {
      isHost = true;
      connectionStatus = 'Создание комнаты...';
    });

    String roomId = _roomController.text.trim();
    if (roomId.isEmpty) roomId = 'default_room';

    _peerConnection = await createPeerConnection(rtcConfig);

    _dataChannel = await _peerConnection!.createDataChannel("chat", RTCDataChannelInit());
    _setupDataChannel();

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null) {
        _dbRef.child('rooms/$roomId/hostCandidates').push().set(candidate.toMap());
      }
    };

    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    await _dbRef.child('rooms/$roomId').set({
      'offer': {'type': offer.type, 'sdp': offer.sdp}
    });

    setState(() {
      connectionStatus = 'Комната создана. Ждем подключение...';
    });

    _dbRef.child('rooms/$roomId/answer').onValue.listen((event) async {
      if (event.snapshot.value != null && _peerConnection!.remoteDescription == null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        RTCSessionDescription answer = RTCSessionDescription(data['sdp'], data['type']);
        await _peerConnection!.setRemoteDescription(answer);
        setState(() {
          connectionStatus = 'Прямое соединение установлено!';
        });
      }
    });

    _dbRef.child('rooms/$roomId/clientCandidates').onChildAdded.listen((event) async {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        RTCIceCandidate candidate = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(candidate);
      }
    });
  }

  Future<void> _joinRoom() async {
    setState(() {
      isHost = false;
      connectionStatus = 'Подключение к комнате...';
    });

    String roomId = _roomController.text.trim();
    if (roomId.isEmpty) roomId = 'default_room';

    _peerConnection = await createPeerConnection(rtcConfig);

    _peerConnection!.onDataChannel = (channel) {
      _dataChannel = channel;
      _setupDataChannel();
      setState(() {
        connectionStatus = 'Прямое соединение установлено!';
      });
    };

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null) {
        _dbRef.child('rooms/$roomId/clientCandidates').push().set(candidate.toMap());
      }
    };

    DatabaseEvent event = await _dbRef.child('rooms/$roomId/offer').once();
    if (event.snapshot.value == null) {
      setState(() {
        connectionStatus = 'Комната не найдена!';
      });
      return;
    }

    final data = Map<String, dynamic>.from(event.snapshot.value as Map);
    RTCSessionDescription offer = RTCSessionDescription(data['sdp'], data['type']);
    await _peerConnection!.setRemoteDescription(offer);

    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await _dbRef.child('rooms/$roomId/answer').set({
      'type': answer.type,
      'sdp': answer.sdp,
    });

    _dbRef.child('rooms/$roomId/hostCandidates').onChildAdded.listen((event) async {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        RTCIceCandidate candidate = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(candidate);
      }
    });
  }

  void _setupDataChannel() {
    _dataChannel!.onMessage = (message) {
      setState(() {
        messages.add('Друг: ${message.text}');
      });
    };
  }

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    String text = _msgController.text.trim();
    
    _dataChannel?.send(RTCDataChannelMessage(text));
    setState(() {
      messages.add('Я: $text');
    });
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('P2P WebRTC Chat')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Статус: $connectionStatus', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(labelText: 'Имя комнаты (например, secret123)'),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: _createRoom, child: const Text('Создать комнату')),
                ElevatedButton(onPressed: _joinRoom, child: const Text('Войти в комнату')),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  return ListTile(title: Text(messages[index]));
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(hintText: 'Введите сообщение...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
