import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // 导入 Uint8List

import 'package:flutter/material.dart';
import 'dart:math'; // 导入 min/max 函数

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Compiler IDE',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const CompilerIDE(),
    );
  }
}

class CompilerIDE extends StatefulWidget {
  const CompilerIDE({super.key});

  @override
  _CompilerIDEState createState() => _CompilerIDEState();
}

class _CompilerIDEState extends State<CompilerIDE> {
  final TextEditingController _codeController = TextEditingController(
    text: '3 + 5 * 2',
  );
  final TextEditingController _outputController = TextEditingController();
  final TextEditingController _serverIpController = TextEditingController(
    text: '127.0.0.1',
  );
  final TextEditingController _serverPortController = TextEditingController(
    text: '12345',
  );

  Socket? _socket;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connectToServer(); // 尝试在应用启动时连接
  }

  @override
  void dispose() {
    _socket?.close();
    _codeController.dispose();
    _outputController.dispose();
    _serverIpController.dispose();
    _serverPortController.dispose();
    super.dispose();
  }

  void _appendToOutput(String message) {
    setState(() {
      _outputController.text += '${message}\n';
    });
  }

  Future<void> _connectToServer() async {
    if (_isConnected) {
      _appendToOutput('Already connected.');
      return;
    }

    final ip = _serverIpController.text;
    final port = int.tryParse(_serverPortController.text);

    if (port == null) {
      _appendToOutput('Invalid port number.');
      return;
    }

    _appendToOutput('Connecting to $ip:$port...');
    try {
      _socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 5),
      );
      _appendToOutput('Connected to $ip:$port');
      setState(() {
        _isConnected = true;
      });

      _socket!.listen(
        (Uint8List data) {
          final response = utf8.decode(data);
          _appendToOutput('Server response: $response');
          // 这里可以解析JSON响应并更新UI
          // 例如:
          // try {
          //   final jsonResponse = jsonDecode(response);
          //   _appendToOutput('Parsed JSON: ${jsonResponse['message']}');
          // } catch (e) {
          //   _appendToOutput('Failed to parse JSON response: $e');
          // }
        },
        onDone: () {
          _appendToOutput('Server disconnected.');
          setState(() {
            _isConnected = false;
          });
          _socket!.destroy();
        },
        onError: (error) {
          _appendToOutput('Socket error: $error');
          setState(() {
            _isConnected = false;
          });
          _socket!.destroy();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _appendToOutput('Connection failed: $e');
      setState(() {
        _isConnected = false;
      });
    }
  }

  Future<void> _disconnectFromServer() async {
    if (!_isConnected) {
      _appendToOutput('Not connected.');
      return;
    }
    _appendToOutput('Disconnecting from server...');
    try {
      await _socket?.close();
      setState(() {
        _isConnected = false;
      });
      _appendToOutput('Disconnected.');
    } catch (e) {
      _appendToOutput('Error disconnecting: $e');
    }
  }

  Future<void> _sendCommand(String command, {String? code}) async {
    if (!_isConnected || _socket == null) {
      _appendToOutput('Not connected to server.');
      return;
    }

    final Map<String, dynamic> request = {'command': command};

    if (code != null) {
      request['code'] = code;
    }

    final jsonString = jsonEncode(request);
    final payload = '$jsonString\n'; // 添加换行符作为消息结束标志

    // --- 调试打印 ---
    _appendToOutput('Sending payload: "$payload"');
    _appendToOutput('Payload string length: ${payload.length}');
    final encodedBytes = utf8.encode(payload);
    _appendToOutput('Encoded bytes length: ${encodedBytes.length}');
    _appendToOutput(
      'First 10 bytes: ${encodedBytes.sublist(0, min(10, encodedBytes.length))}',
    );
    _appendToOutput(
      'Last 10 bytes: ${encodedBytes.sublist(max(0, encodedBytes.length - 10), encodedBytes.length)}',
    );
    // --- 调试打印结束 ---

    try {
      _socket!.write(encodedBytes);
      await _socket!.flush(); // 确保数据被立即发送
      _appendToOutput('Command "$command" sent successfully.');
    } catch (e) {
      _appendToOutput('Error sending command: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compiler IDE'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SizedBox(
              width: 120,
              child: TextField(
                controller: _serverIpController,
                decoration: const InputDecoration(
                  labelText: 'Server IP',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SizedBox(
              width: 80,
              child: TextField(
                controller: _serverPortController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          IconButton(
            icon: Icon(_isConnected ? Icons.link_off : Icons.link),
            onPressed: _isConnected ? _disconnectFromServer : _connectToServer,
            tooltip: _isConnected ? 'Disconnect' : 'Connect',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _codeController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'Enter your code here...',
                  border: OutlineInputBorder(),
                  labelText: 'Code Editor',
                ),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: _isConnected
                      ? () =>
                            _sendCommand('compile', code: _codeController.text)
                      : null,
                  child: const Text('Compile'),
                ),
                ElevatedButton(
                  onPressed: _isConnected
                      ? () => _sendCommand('vm_step')
                      : null,
                  child: const Text('VM Step'),
                ),
                ElevatedButton(
                  onPressed: _isConnected
                      ? () => _sendCommand('vm_reset')
                      : null,
                  child: const Text('VM Reset'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _outputController,
                maxLines: null,
                expands: true,
                readOnly: true,
                decoration: const InputDecoration(
                  hintText: 'Output will appear here...',
                  border: OutlineInputBorder(),
                  labelText: 'Output Console',
                ),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
