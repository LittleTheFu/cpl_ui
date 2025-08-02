import 'dart:io'; // 用于Socket通信
import 'dart:convert'; // 用于JSON编解码
import 'package:flutter/material.dart';

// ... (main函数和MyApp类，保持不变)

class DebuggerScreen extends StatefulWidget {
  const DebuggerScreen({super.key});

  @override
  _DebuggerScreenState createState() => _DebuggerScreenState();
}

class _DebuggerScreenState extends State<DebuggerScreen> {
  Socket? _socket;
  final String _serverIp = '127.0.0.1'; // C++ 服务器的IP地址
  final int _serverPort = 12345; // C++ 服务器的端口

  final TextEditingController _codeController = TextEditingController();
  String _responseMessage = 'No response yet.';
  // ... 其他用于显示VM状态的变量

  @override
  void initState() {
    super.initState();
    _connectToServer(); // Widget 初始化时尝试连接服务器
  }

  @override
  void dispose() {
    _socket?.close(); // Widget 销毁时关闭Socket
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _connectToServer() async {
    try {
      // 步骤 2: 连接到服务器
      _socket = await Socket.connect(_serverIp, _serverPort);
      setState(() {
        _responseMessage = 'Connected to C++ server!';
      });
      print(
        'Connected to C++ server: ${_socket!.remoteAddress.address}:${_socket!.remotePort}',
      );

      // 步骤 4: 监听服务器发送的数据
      _socket!.listen(
        (List<int> data) {
          final responseString = utf8.decode(data).trim(); // 解码并移除空白符
          print('Received from server: $responseString');
          _handleServerResponse(responseString); // 处理服务器响应
        },
        onDone: () {
          // 步骤 5: 处理连接关闭
          setState(() {
            _responseMessage = 'Server disconnected.';
            _socket = null;
          });
          print('Server disconnected.');
        },
        onError: (error) {
          // 步骤 5: 处理Socket错误
          setState(() {
            _responseMessage = 'Socket error: $error';
            _socket = null;
          });
          print('Socket error: $error');
        },
      );
    } catch (e) {
      // 步骤 5: 处理连接失败
      setState(() {
        _responseMessage = 'Failed to connect: $e';
        _socket = null;
      });
      print('Failed to connect to server: $e');
    }
  }

  Future<void> _sendMessage(Map<String, dynamic> message) async {
    if (_socket == null) {
      setState(() {
        _responseMessage = 'Not connected to server.';
      });
      print('Error: Socket not connected.');
      return;
    }

    // 步骤 3: 发送请求
    final jsonString = jsonEncode(message);
    final payload = '$jsonString\n'; // 加上换行符作为消息结束标志
    _socket!.write(utf8.encode(payload)); // 编码为UTF-8字节并发送
    print('Sent to server: $jsonString');
  }

  void _handleServerResponse(String responseString) {
    try {
      final jsonResponse = jsonDecode(responseString); // 解析JSON响应
      setState(() {
        _responseMessage = jsonResponse['message'] ?? 'Unknown response.';
        // 根据响应类型更新UI状态 (例如，编译结果、VM状态等)
        if (jsonResponse['status'] == 'success') {
          if (jsonResponse['type'] == 'compiled_code') {
            // ... 更新_assemblyLines等
          } else if (jsonResponse['type'] == 'vm_state') {
            // ... 更新_currentPc, _vmHalted, _registers等
          }
        }
      });
    } catch (e) {
      setState(() {
        _responseMessage = 'Error parsing response: $e\nRaw: $responseString';
      });
      print('Error parsing server response: $e\nRaw: $responseString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... UI布局，包含文本输入框、按钮、状态显示等
      // 按钮的onPressed回调中调用_sendMessage，传入不同的command和数据
      // 例如：
      // ElevatedButton(
      //   onPressed: () {
      //     _sendMessage({'command': 'compile', 'code': _codeController.text});
      //   },
      //   child: const Text('Compile'),
      // ),
      // ElevatedButton(
      //   onPressed: () {
      //     _sendMessage({'command': 'vm_step'});
      //   },
      //   child: const Text('VM Step'),
      // ),
    );
  }
}
