import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Assembly Code Viewer',
      theme: ThemeData(
        brightness: Brightness.dark, // 使用暗色主题，代码显示效果更好
        primarySwatch: Colors.blueGrey,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.blueGrey),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 模拟的汇编代码数据
  final String _fakeAssemblyCode = """
  .data
  myVar: .word 10
  anotherVar: .byte 5

  .text
  start:
    LOAD R0, #myVar     ; Load value of myVar into R0
    ADD R0, #5          ; Add 5 to R0
    STORE R0, #anotherVar ; Store R0 into anotherVar
    CALL sub_func       ; Call a subroutine
    PRINT R0            ; Print the value in R0
    JMP end             ; Jump to end

  sub_func:
    PUSH R1             ; Save R1
    LOAD R1, #20        ; Load 20 into R1
    ADD R0, R1          ; Add R1 to R0
    POP R1              ; Restore R1
    RET                 ; Return from subroutine

  end:
    HALT                ; Stop execution
  """;

  // 模拟当前高亮的行号，从0开始计数
  int _currentHighlightedLine = 0;

  // 模拟VM执行一步，更新高亮行
  void _stepExecution() {
    setState(() {
      final int totalLines = _fakeAssemblyCode.split('\n').length;
      _currentHighlightedLine = (_currentHighlightedLine + 1) % totalLines;
    });
  }

  // 模拟重置高亮行
  void _resetExecution() {
    setState(() {
      _currentHighlightedLine = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assembly Code Debugger')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              // 这里使用我们自定义的 AssemblyCodeViewer Widget
              child: AssemblyCodeViewer(
                assemblyCode: _fakeAssemblyCode,
                highlightedLine: _currentHighlightedLine,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: _stepExecution,
                  child: const Text('Step (Next Line)'),
                ),
                ElevatedButton(
                  onPressed: _resetExecution,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// AssemblyCodeViewer Widget - 负责显示汇编代码的核心组件
// 这是一个 StatelessWidget，因为它只负责根据传入的数据渲染UI
// ==========================================================
class AssemblyCodeViewer extends StatelessWidget {
  final String assemblyCode;
  final int highlightedLine; // 从0开始的行号

  const AssemblyCodeViewer({
    super.key,
    required this.assemblyCode,
    required this.highlightedLine,
  });

  @override
  Widget build(BuildContext context) {
    // 将汇编代码字符串按行分割
    final List<String> lines = assemblyCode.split('\n');

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900], // 代码区域背景色
        border: Border.all(color: Colors.grey.shade700),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(8.0),
      child: ListView.builder(
        itemCount: lines.length,
        itemBuilder: (context, index) {
          // 判断当前行是否需要高亮
          final bool isHighlighted = index == highlightedLine;

          return Container(
            // 高亮行的背景颜色，使用半透明黄色
            color: isHighlighted
                ? Colors.yellow.withOpacity(0.2)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start, // 行号和代码顶部对齐
              children: [
                // 行号显示区域
                SizedBox(
                  width: 40, // 给行号留出固定宽度，适应更多位数
                  child: Text(
                    '${index + 1}', // 显示1-indexed行号
                    style: TextStyle(
                      color: isHighlighted
                          ? Colors.yellowAccent
                          : Colors.grey[600],
                      fontFamily: 'monospace', // 等宽字体更适合代码
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.right, // 行号右对齐
                  ),
                ),
                const SizedBox(width: 8), // 行号和代码之间的间距
                // 汇编代码行文本
                Expanded(
                  // 确保代码文本占据剩余空间
                  child: Text(
                    lines[index],
                    style: TextStyle(
                      color: isHighlighted ? Colors.white : Colors.grey[300],
                      fontFamily: 'monospace', // 等宽字体更适合代码
                      fontSize: 14,
                      fontWeight: isHighlighted
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
