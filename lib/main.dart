import 'package:flutter/material.dart';
import 'package:testflutter/ffi_bridge.dart'; // 导入 ffi_bridge.dart

// Solarized Dark-inspired color palette
const Color _solBase03 = Color(0xFF002b36); // Background
const Color _solBase02 = Color(0xFF073642); // Highlight Background
const Color _solBase01 = Color(0xFF586e75); // Comments/Muted Text
const Color _solBase0 = Color(0xFF839496); // Body Text
const Color _solGreen = Color(0xFF859900); // Green (Instructions, True Flag)
const Color _solCyan = Color(0xFF2aa198); // Cyan (Memory, Register Values)
const Color _solRed = Color(0xFFdc322f); // Red (False Flag)
const Color _solBlue = Color(0xFF268bd2); // Blue (AppBar, Highlight)

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
        primaryColor: _solBlue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _solBase03,
        fontFamily: 'monospace',
        appBarTheme: const AppBarTheme(
          backgroundColor: _solBase02,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: _solBase0,
            fontFamily: 'monospace',
            fontSize: 18,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _solBase02,
          labelStyle: const TextStyle(
            color: _solBase0,
            fontFamily: 'monospace',
          ),
          secondaryLabelStyle: const TextStyle(
            color: _solBase0,
            fontFamily: 'monospace',
          ),
          selectedColor: _solBlue,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: _solBlue,
        ),
        dividerColor: _solBase01,
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
  final TextEditingController _sourceCodeController = TextEditingController(text: "1+2*3");
  List<String> _assemblyCodeLines = ["请在上方输入源代码并点击 \"编译并上传源代码\" 按钮"];
  String _errorMessage = ""; // New state variable for error messages
  int _currentPc = -1;
  List<int> _registers = []; // 用于存储寄存器值
  bool _zeroFlag = false;
  bool _signFlag = false;
  List<int> _memory = []; // 用于存储内存内容
  final ScrollController _scrollController = ScrollController();
  static const double _itemHeight = 24.0; // 假设每个列表项的固定高度

  @override
  void initState() {
    super.initState();
    _loadAssemblyCode();
  }

  @override
  void dispose() {
    _sourceCodeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentLine() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _currentPc >= 0) {
        final viewportHeight = 300.0;
        final itemPosition = _currentPc * _itemHeight;
        var offset = itemPosition - (viewportHeight / 2) + (_itemHeight / 2);

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
    // This method will now be used to update the UI based on the _assemblyCodeLines
    // It will be called after _uploadSourceCode or resetProgram
    final int pc = NativeCompilerBridge.getVmPc();
    final List<int> registers = NativeCompilerBridge.getVmAllRegisters();
    final bool zf = NativeCompilerBridge.getVmZeroFlag();
    final bool sf = NativeCompilerBridge.getVmSignFlag();
    final List<int> memory = NativeCompilerBridge.getVmAllMemory();
    setState(() {
      _currentPc = pc;
      _registers = registers;
      _zeroFlag = zf;
      _signFlag = sf;
      _memory = memory;
    });
    _scrollToCurrentLine();
  }

  Future<void> _uploadSourceCode() async {
    final String sourceCode = _sourceCodeController.text;
    if (sourceCode.isEmpty) {
      setState(() {
        _assemblyCodeLines = ["请输入源代码"];
        _errorMessage = ""; // Clear error message if source code is empty
      });
      return;
    }

    try {
      final List<String> compiledCode = NativeCompilerBridge.uploadSourceCode(
        sourceCode,
      );
      setState(() {
        _assemblyCodeLines = compiledCode;
        _errorMessage = ""; // Clear error message on success
      });
      _loadAssemblyCode(); // Update other VM states
    } catch (e) {
      setState(() {
        _assemblyCodeLines = []; // Clear assembly code on error
        _errorMessage = "编译错误: $e"; // Set error message
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('汇编代码查看器'), centerTitle: true),
      body: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _sourceCodeController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: '在此输入源代码...',
                      border: OutlineInputBorder(),
                      fillColor: _solBase02,
                      filled: true,
                    ),
                    style: TextStyle(color: _solBase0, fontFamily: 'monospace'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 50), // Minimum height for the box
                    decoration: BoxDecoration(
                      border: Border.all(color: _solBase01), // Border color
                      borderRadius: BorderRadius.circular(4.0), // Rounded corners
                    ),
                    padding: const EdgeInsets.all(8.0),
                    alignment: Alignment.topLeft, // Align text to top-left
                    child: _errorMessage.isNotEmpty
                        ? Text(
                            _errorMessage,
                            style: const TextStyle(color: _solRed, fontSize: 16),
                          )
                        : Text(
                            "错误信息将显示在此处", // Placeholder text when empty
                            style: TextStyle(color: Color.fromARGB((255 * 0.6).round(), 0x58, 0x6e, 0x75), fontStyle: FontStyle.italic),
                          ),
                  ),
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _uploadSourceCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: _solBlue,
              foregroundColor: _solBase03,
            ),
            child: const Text('编译并上传源代码'),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Assembly Code View
                SizedBox(
                  height: double.infinity,
                  width: 400,
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    color: _solBase03,
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
                          color: isCurrentPc ? _solBase02 : Colors.transparent,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    lineNumber,
                                    style: const TextStyle(
                                      color: _solBase01,
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
                                      color: _solGreen,
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
                const VerticalDivider(width: 1, color: _solBase01),
                // Register View
                SizedBox(
                  height: double.infinity,
                  width: 200,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          const Text(
                            "Registers",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _solBase0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: [
                              ...List<Widget>.generate(_registers.length, (index) {
                                return Chip(
                                  label: Text('R$index: ${_registers[index]}'),
                                );
                              }),
                              Chip(
                                label: const Text(
                                  'ZF',
                                  style: TextStyle(color: _solBase03),
                                ),
                                backgroundColor: _zeroFlag ? _solGreen : _solRed,
                              ),
                              Chip(
                                label: const Text(
                                  'SF',
                                  style: TextStyle(color: _solBase03),
                                ),
                                backgroundColor: _signFlag ? _solGreen : _solRed,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, color: _solBase01),
                // Memory View
                Expanded(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          "Memory View",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _solBase0,
                          ),
                        ),
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
                                      style: const TextStyle(color: _solBase01),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '0x${_memory[index].toRadixString(16).padLeft(8, '0')}',
                                      style: const TextStyle(color: _solCyan),
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
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            onPressed: () {
              NativeCompilerBridge.resetProgram();
              _loadAssemblyCode();
            },
            tooltip: 'Reset Program',
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            onPressed: () {
              NativeCompilerBridge.stepVm();
              final int pc = NativeCompilerBridge.getVmPc();
              final List<int> registers =
                  NativeCompilerBridge.getVmAllRegisters();
              final bool zf = NativeCompilerBridge.getVmZeroFlag();
              final bool sf = NativeCompilerBridge.getVmSignFlag();
              final List<int> memory = NativeCompilerBridge.getVmAllMemory();
              setState(() {
                _currentPc = pc;
                _registers = registers;
                _zeroFlag = zf;
                _signFlag = sf;
                _memory = memory;
              });
              _scrollToCurrentLine();
            },
            tooltip: 'Step',
            child: const Icon(Icons.play_arrow),
          ),
        ],
      ),
    );
  }
}
