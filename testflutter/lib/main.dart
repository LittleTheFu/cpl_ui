import 'package:flutter/material.dart';
import 'package:testflutter/ffi_bridge.dart'; // 导入 ffi_bridge.dart

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '汇编代码显示',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        brightness: Brightness.dark, // 使用暗色主题，更适合代码显示
        fontFamily: 'monospace', // 尝试使用等宽字体
      ),
      home: const AssemblyCodeView(),
    );
  }
}

class AssemblyCodeView extends StatefulWidget {
  const AssemblyCodeView({super.key});

  @override
  State<AssemblyCodeView> createState() => _AssemblyCodeViewState();
}

class _AssemblyCodeViewState extends State<AssemblyCodeView> {
  List<String> _assemblyCodeLines = []; // 初始化为空列表
  int _currentPc = -1; // 当前 VM PC，初始化为 -1

  @override
  void initState() {
    super.initState();
    _loadAssemblyCode();
  }

  Future<void> _loadAssemblyCode() async {
    final List<String> code = NativeCompilerBridge.getHardcodedVmAssemblyCode();
    final int pc = NativeCompilerBridge.getVmPc(); // 获取当前 PC
    setState(() {
      _assemblyCodeLines = code;
      _currentPc = pc; // 更新当前 PC
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('汇编代码查看器'), centerTitle: true),
      body: Container(
        padding: const EdgeInsets.all(8.0),
        color: Colors.grey[900], // 背景色更深，突出代码
        child: ListView.builder(
          itemCount: _assemblyCodeLines.length,
          itemBuilder: (context, index) {
            final line = _assemblyCodeLines[index];
            // 分割行号和指令，假设格式为 "行号: 指令"
            final parts = line.split(': ');
            String lineNumber = parts.length > 1 ? parts[0] : '';
            String instruction = parts.length > 1 ? parts[1] : line;

            // 判断是否是当前 PC 行
            final bool isCurrentPc = index == _currentPc;

            return Container(
              color: isCurrentPc ? Colors.blueAccent.withOpacity(0.3) : Colors.transparent, // 高亮当前行
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 行号部分
                    SizedBox(
                      width: 60, // 固定宽度，确保行号对齐
                      child: Text(
                        lineNumber,
                        style: TextStyle(
                          color: Colors.grey[600], // 行号颜色更浅
                          fontFamily: 'monospace',
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 汇编指令部分
                    Expanded(
                      child: Text(
                        instruction,
                        style: const TextStyle(
                          color: Colors.lightGreenAccent, // 汇编指令颜色
                          fontFamily: 'monospace',
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
