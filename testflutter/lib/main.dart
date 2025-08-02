import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // 导入 Uint8List
import 'dart:async'; // 导入 Completer

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
  // ✅ 新增：用于在 _sendCommand 中等待响应的 Completer
  Completer<String>? _responseCompleter;

  @override
  void initState() {
    super.initState();
    print('FLUTTER DEBUG: initState entered.'); // 新增调试打印
    _connectToServer(); // 尝试在应用启动时连接
    print('FLUTTER DEBUG: _connectToServer called from initState.'); // 新增调试打印
  }

  @override
  void dispose() {
    _socket?.close();
    // ✅ 确保 Completer 在 dispose 时也被完成或取消
    if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
      _responseCompleter!.completeError(
        'Socket disposed before response received.',
      );
      print(
        'FLUTTER DEBUG: _responseCompleter completed with error during dispose.',
      );
    }
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
    print('FLUTTER DEBUG: _connectToServer entered.'); // 新增调试打印
    if (_isConnected) {
      _appendToOutput('Already connected.');
      print('FLUTTER DEBUG: Already connected, returning.'); // 新增调试打印
      return;
    }

    final ip = _serverIpController.text;
    final port = int.tryParse(_serverPortController.text);

    if (port == null) {
      _appendToOutput('Invalid port number.');
      print('FLUTTER DEBUG: Invalid port, returning.'); // 新增调试打印
      return;
    }

    _appendToOutput('Connecting to $ip:$port...');
    try {
      print('FLUTTER DEBUG: Attempting Socket.connect.'); // 新增调试打印
      _socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 5),
      );
      _appendToOutput('Connected to $ip:$port');
      print('FLUTTER DEBUG: Socket connected successfully.'); // 新增调试打印
      setState(() {
        _isConnected = true;
      });

      _socket!.listen(
        (Uint8List data) {
          print('FLUTTER DEBUG: Data received!');
          final response = utf8.decode(data);
          _appendToOutput('Server response: $response');
          // ✅ 收到数据时，完成 Completer
          if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
            _responseCompleter!.complete(response);
            print('FLUTTER DEBUG: Completer completed with response.');
          } else {
            print(
              'FLUTTER DEBUG: Data received but no active completer or already completed.',
            );
          }
        },
        onDone: () {
          print('FLUTTER DEBUG: Connection Done!');
          _appendToOutput('Server disconnected.');
          setState(() {
            _isConnected = false;
          });
          // ✅ 当连接关闭时，用错误完成 Completer
          if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
            _responseCompleter!.completeError('Socket disconnected.');
            print(
              'FLUTTER DEBUG: Completer completed with error: Socket disconnected.',
            );
          }
          _socket!.destroy();
        },
        onError: (error) {
          print('FLUTTER DEBUG: Socket Error! $error');
          _appendToOutput('Socket error: $error');
          setState(() {
            _isConnected = false;
          });
          // ✅ 当发生错误时，用错误完成 Completer
          if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
            _responseCompleter!.completeError('Socket error: $error');
            print(
              'FLUTTER DEBUG: Completer completed with error: Socket error: $error',
            );
          }
          _socket!.destroy();
        },
        cancelOnError: true,
      );
      print('FLUTTER DEBUG: Socket listener set up.'); // 新增调试打印
    } catch (e) {
      _appendToOutput('Connection failed: $e');
      print('FLUTTER DEBUG: Connection failed in catch block: $e'); // 新增调试打印
      setState(() {
        _isConnected = false;
      });
      // ✅ 连接失败时，也确保 Completer 错误完成
      if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
        _responseCompleter!.completeError('Connection failed: $e');
        print(
          'FLUTTER DEBUG: Completer completed with error: Connection failed: $e',
        );
      }
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

    // ✅ 重置 Completer
    // 确保每次新的命令都对应一个新的 Completer
    _responseCompleter = Completer<String>();
    print('FLUTTER DEBUG: New _responseCompleter created.');

    final Map<String, dynamic> request = {'command': command};
    if (code != null) {
      request['code'] = code;
    }
    final jsonString = jsonEncode(request);
    final payload = '$jsonString\n'; // 添加换行符作为消息结束标志

    // --- 调试打印 (保留) ---
    _appendToOutput('Sending payload: "$payload"');
    _appendToOutput('Payload string length: ${payload.length}');
    final encodedBytes = utf8.encode(payload); // 这是一个 Uint8List，包含了原始的字节数据
    _appendToOutput('Encoded bytes length: ${encodedBytes.length}');
    _appendToOutput(
      'First 10 bytes: ${encodedBytes.sublist(0, min(10, encodedBytes.length))}',
    );
    _appendToOutput(
      'Last 10 bytes: ${encodedBytes.sublist(max(0, encodedBytes.length - 10), encodedBytes.length)}',
    );
    // --- 调试打印结束 ---

    try {
      _socket!.add(encodedBytes);
      await _socket!.flush(); // 确保数据被立即发送
      _appendToOutput('Command "$command" sent successfully.');
      print('FLUTTER DEBUG: Payload sent and flushed.');

      // ✅ 关键：等待响应
      print('FLUTTER DEBUG: Waiting for server response via Completer...');
      String serverResponse = await _responseCompleter!.future.timeout(
        const Duration(seconds: 5), // 设置超时时间
        onTimeout: () {
          print('FLUTTER DEBUG: Server response timeout after 5 seconds.');
          // 在超时时抛出异常，或者返回一个特定的错误消息
          throw TimeoutException('Server did not respond within 5 seconds.');
        },
      );
      _appendToOutput(
        'FLUTTER DEBUG: Received response after waiting: $serverResponse',
      );
    } catch (e) {
      _appendToOutput('Error sending command or waiting for response: $e');
      print('FLUTTER DEBUG: Exception in _sendCommand: $e');
    } finally {
      // ✅ 确保 Completer 在请求处理完成后被清空或重置
      // 避免 Completer 被多次完成的错误
      if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
        _responseCompleter!.completeError(
          'Request finished or timed out before completer was explicitly completed.',
        );
        print('FLUTTER DEBUG: Completer force-completed in finally block.');
      }
      _responseCompleter = null;
      print('FLUTTER DEBUG: _responseCompleter set to null.');
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
