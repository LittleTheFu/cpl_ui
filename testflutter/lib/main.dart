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
  List<String> _assemblyCodeLines = [];
  int _currentPc = -1;
  List<int> _registers = []; // 用于存储寄存器值
  bool _zeroFlag = false;
  bool _signFlag = false;
  List<int> _memory = []; // 用于存储内存内容
  final ScrollController _scrollController = ScrollController();
  static const double _itemHeight = 20.0; // 假设每个列表项的固定高度

  @override
  void initState() {
    super.initState();
    _loadAssemblyCode();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentLine() {
    // 确保UI构建完成后再滚动
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _currentPc >= 0) {
        final viewportHeight = 300.0; // 视图高度
        final itemPosition = _currentPc * _itemHeight;
        var offset = itemPosition - (viewportHeight / 2) + (_itemHeight / 2);

        // 限制偏移量，防止超出滚动范围
        if (offset < 0) {
          offset = 0;
        }
        if (offset > _scrollController.position.maxScrollExtent) {
          offset = _scrollController.position.maxScrollExtent;
        }

        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadAssemblyCode() async {
    final List<String> code = NativeCompilerBridge.getHardcodedVmAssemblyCode();
    final int pc = NativeCompilerBridge.getVmPc();
    final List<int> registers = NativeCompilerBridge.getVmAllRegisters();
    final bool zf = NativeCompilerBridge.getVmZeroFlag();
    final bool sf = NativeCompilerBridge.getVmSignFlag();
    final List<int> memory = NativeCompilerBridge.getVmAllMemory();
    setState(() {
      _assemblyCodeLines = code;
      _currentPc = pc;
      _registers = registers;
      _zeroFlag = zf;
      _signFlag = sf;
      _memory = memory;
    });
    _scrollToCurrentLine();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('汇编代码查看器'), centerTitle: true),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Assembly Code View
          SizedBox(
            height: double.infinity,
            width: 400,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.grey[900],
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _assemblyCodeLines.length,
                itemBuilder: (context, index) {
                  final line = _assemblyCodeLines[index];
                  final parts = line.split(': ');
                  String lineNumber = parts.length > 1 ? parts[0] : '';
                  String instruction = parts.length > 1 ? parts[1] : line;
                  final bool isCurrentPc = index == _currentPc;

                  return Container(
                    height: _itemHeight,
                    color: isCurrentPc
                        ? Colors.blueAccent.withAlpha((255 * 0.3).round())
                        : Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(
                              lineNumber,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontFamily: 'monospace',
                                fontSize: 14.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 300,
                            child: Text(
                              instruction,
                              style: const TextStyle(
                                color: Colors.lightGreenAccent,
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
          ),
          const VerticalDivider(),
          // Register View
          SizedBox(
            height: double.infinity,
            width: 200,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    const Text("Registers", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: [
                        ...List<Widget>.generate(_registers.length, (index) {
                          return Chip(
                            label: Text(
                              'R$index: ${_registers[index]}',
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          );
                        }),
                        Chip(
                          label: Text(
                            'ZF: ${_zeroFlag ? 1 : 0}',
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                          backgroundColor: _zeroFlag ? Colors.green : Colors.red,
                        ),
                        Chip(
                          label: Text(
                            'SF: ${_signFlag ? 1 : 0}',
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                          backgroundColor: _signFlag ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const VerticalDivider(),
          // Memory View
          Expanded(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("Memory View", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ListView.builder(
                      itemCount: _memory.length,
                      itemBuilder: (context, index) {
                        return SizedBox(
                          height: _itemHeight,
                          child: Row(
                            children: [
                              Text(
                                '0x${(index).toRadixString(16).padLeft(8, '0')}:',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '0x${_memory[index].toRadixString(16).padLeft(8, '0')}',
                                style: const TextStyle(color: Colors.cyanAccent),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            onPressed: () {
              // 调用 resetProgram 并重新加载代码
              NativeCompilerBridge.resetProgram();
              _loadAssemblyCode();
            },
            tooltip: 'Reset Program',
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            onPressed: () {
              NativeCompilerBridge.stepVm(); // 调用 stepVm
              final int pc = NativeCompilerBridge.getVmPc();
              final List<int> registers = NativeCompilerBridge.getVmAllRegisters();
              final bool zf = NativeCompilerBridge.getVmZeroFlag();
              final bool sf = NativeCompilerBridge.getVmSignFlag();
              final List<int> memory = NativeCompilerBridge.getVmAllMemory();
              setState(() {
                _currentPc = pc; // 更新 PC 并刷新 UI
                _registers = registers;
                _zeroFlag = zf;
                _signFlag = sf;
                _memory = memory;
              });
              _scrollToCurrentLine();
            },
            tooltip: 'Step',
            child: const Icon(Icons.play_arrow), // 播放图标
          ),
        ],
      ),
    );
  }
}
