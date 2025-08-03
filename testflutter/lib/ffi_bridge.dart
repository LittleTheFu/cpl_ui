import 'dart:ffi';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:ffi/ffi.dart'; // Add this import

// 定义 Dart 中的 StringArray 结构体，必须精确匹配 C++ 中的定义
// C++ struct:
// struct StringArray {
//   char** strings;
//   size_t count;
// };
final class StringArray extends Struct {
  external Pointer<Pointer<Char>> strings;

  @Size()
  external int count;
}

// 定义 C++ 函数的签名
typedef GetAssemblyCodeForUiC = Pointer<StringArray> Function();
typedef GetAssemblyCodeForUiDart = Pointer<StringArray> Function();

// 定义 C++ 释放函数签名
typedef FreeStringArrayC = Void Function(Pointer<StringArray> array);
typedef FreeStringArrayDart = void Function(Pointer<StringArray> array);

class NativeCompilerBridge {
  static final DynamicLibrary _dylib = _openDynamicLibrary();

  static DynamicLibrary _openDynamicLibrary() {
    if (Platform.isWindows) {
      // 假设 DLL 放在 Flutter 项目根目录下的 'dll' 文件夹中
      return DynamicLibrary.open(
        p.join(Directory.current.path, 'dll', 'ffi_api.dll'),
      );
    } else if (Platform.isMacOS) {
      // 假设 .dylib 放在 Flutter 项目根目录下的 'dylib' 文件夹中
      return DynamicLibrary.open(
        p.join(Directory.current.path, 'dylib', 'libffi_api.dylib'),
      );
    } else if (Platform.isLinux) {
      // 假设 .so 放在 Flutter 项目根目录下的 'so' 文件夹中
      return DynamicLibrary.open(
        p.join(Directory.current.path, 'so', 'libffi_api.so'),
      );
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // 获取 C++ 函数的 Dart 绑定
  static final _getAssemblyCodeForUi = _dylib
      .lookupFunction<GetAssemblyCodeForUiC, GetAssemblyCodeForUiDart>(
        'get_assembly_code_for_ui',
      );

  static final _freeStringArray = _dylib
      .lookupFunction<FreeStringArrayC, FreeStringArrayDart>(
        'free_string_array',
      );

  /// 调用 C++ 函数获取汇编代码列表
  static List<String> getAssemblyCode() {
    final Pointer<StringArray> nativeArrayPtr = _getAssemblyCodeForUi();

    // 检查返回的指针是否有效
    if (nativeArrayPtr == nullptr) {
      print("[Dart] C++ returned a null StringArray pointer.");
      return [];
    }

    try {
      // 从 StringArray 结构体中读取 count 和 strings 数组
      final int count = nativeArrayPtr.ref.count;
      final Pointer<Pointer<Char>> nativeStrings = nativeArrayPtr.ref.strings;

      // 将每个 Utf8 指针转换为 Dart String
      final List<String> dartCodeLines = [];
      for (int i = 0; i < count; i++) {
        dartCodeLines.add(nativeStrings[i].cast<Utf8>().toDartString());
      }
      
      return dartCodeLines;
    } finally {
      // 确保无论如何都释放 C++ 端分配的内存
      _freeStringArray(nativeArrayPtr);
    }
  }
}
