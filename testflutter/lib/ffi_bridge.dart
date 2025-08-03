// ffi_bridge.dart
import 'dart:ffi';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:ffi/ffi.dart'; // Make sure this is imported for Utf8 and other ffi utilities

// Define Dart 中的 StringArray 结构体，必须精确匹配 C++ 中的定义
final class StringArray extends Struct {
  external Pointer<Pointer<Char>> strings;

  @Size()
  external int count;
}

// Define Dart 中的 IntArray 结构体，精确匹配 C++ 中的定义
final class IntArray extends Struct {
  external Pointer<Int32> data; // C++ 结构体中是 data，不是 ints
  @Size()
  external int count;
}

// Extension to easily convert the C StringArray pointer to a Dart List<String>
extension StringArrayPointer on Pointer<StringArray> {
  List<String> toDartStrings() {
    final List<String> result = [];
    if (this == nullptr || ref.strings == nullptr) {
      return result; // Handle null pointers gracefully
    }
    for (int i = 0; i < ref.count; i++) {
      // Ensure the inner pointer is also not null before converting
      final Pointer<Char> charPtr = ref.strings[i];
      if (charPtr != nullptr) {
        result.add(charPtr.cast<Utf8>().toDartString());
      } else {
        result.add(''); // Add an empty string for null C strings
      }
    }
    return result;
  }
}

// Extension to easily convert the C IntArray **value** to a Dart List<int>
// 注意：这个扩展现在是作用在 IntArray **值**上，而不是 Pointer<IntArray>
extension IntArrayExtension on IntArray {
  List<int> toDartInts() {
    final List<int> result = [];
    if (data == nullptr) {
      // 如果 C++ 端返回了空的 data 指针，直接返回空列表
      return result;
    }
    // 使用 asTypedList 创建一个视图，然后使用 .toList() 复制到 Dart 堆。
    // 这行是正确的，它直接操作 IntArray 结构体中的 `data` 成员
    return data.asTypedList(count).toList();
  }
}

// --- FFI Function Type Definitions ---

// C 函数签名
// **修正：get_vm_all_registers 返回 IntArray 值**
typedef GetVmAllRegistersC = IntArray Function();
typedef GetVmAllRegistersDart = IntArray Function();

// **修正：free_int_array_data 接收 Pointer<Int32> (int*)**
typedef FreeIntArrayDataC = Void Function(Pointer<Int32> data);
typedef FreeIntArrayDataDart = void Function(Pointer<Int32> data);

// 其他函数保持不变，因为它们在 C++ 端是单例调用，不需要 WorkShop* 参数
typedef GetHardcodedVmInstructionsC = Pointer<StringArray> Function();
typedef GetHardcodedVmInstructionsDart = Pointer<StringArray> Function();

typedef FreeStringArrayC = Void Function(Pointer<StringArray> array);
typedef FreeStringArrayDart = void Function(Pointer<StringArray> array);

typedef GetVmPcC = IntPtr Function();
typedef GetVmPcDart = int Function();

typedef StepVmC = Void Function();
typedef StepVmDart = void Function();

typedef ResetVMProgramC = Void Function();
typedef ResetVMProgramDart = void Function();

/// A bridge to call native C++ functions for compiler operations.
class NativeCompilerBridge {
  static final DynamicLibrary _dylib = _openDynamicLibrary();

  static DynamicLibrary _openDynamicLibrary() {
    if (Platform.isWindows) {
      return DynamicLibrary.open(
        p.join(Directory.current.path, 'dll', 'cpl_ffi_lib.dll'),
      );
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open(
        p.join(Directory.current.path, 'lib', 'libcpl_ffi_lib.dylib'),
      );
    } else if (Platform.isLinux) {
      return DynamicLibrary.open(
        p.join(Directory.current.path, 'lib', 'libcpl_ffi_lib.so'),
      );
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // Lookup the C++ functions and bind them to Dart functions
  static final _getHardcodedVmInstructions = _dylib
      .lookupFunction<
        GetHardcodedVmInstructionsC,
        GetHardcodedVmInstructionsDart
      >('get_hardcoded_vm_instructions');

  static final _freeStringArray = _dylib
      .lookupFunction<FreeStringArrayC, FreeStringArrayDart>(
        'free_string_array',
      );

  // **修正：查找 free_int_array_data 函数**
  static final _freeIntArrayData = _dylib
      .lookupFunction<FreeIntArrayDataC, FreeIntArrayDataDart>(
        'free_int_array_data',
      );

  static final _getVmPc = _dylib.lookupFunction<GetVmPcC, GetVmPcDart>(
    'get_vm_pc',
  );

  static final _resetProgram = _dylib
      .lookupFunction<ResetVMProgramC, ResetVMProgramDart>('reset_vm_program');

  static final _stepVm = _dylib.lookupFunction<StepVmC, StepVmDart>('step_vm');

  // **修正：查找 get_vm_all_registers 函数**
  static final _getVmAllRegisters = _dylib
      .lookupFunction<GetVmAllRegistersC, GetVmAllRegistersDart>(
        'get_vm_all_registers',
      );

  /// Calls the C++ function to retrieve the hardcoded VM instruction assembly code.
  ///
  /// It manages memory by automatically freeing the C++ allocated `StringArray`.
  static List<String> getHardcodedVmAssemblyCode() {
    final Pointer<StringArray> nativeArrayPtr = _getHardcodedVmInstructions();

    if (nativeArrayPtr == nullptr) {
      print(
        "[Dart] C++ returned a null StringArray pointer for hardcoded instructions.",
      );
      return [];
    }

    try {
      final List<String> dartCodeLines = nativeArrayPtr.toDartStrings();
      return dartCodeLines;
    } finally {
      // Ensure the C++ allocated memory is always freed
      _freeStringArray(nativeArrayPtr);
    }
  }

  /// Calls the C++ function to retrieve the current VM program counter (PC).
  /// Returns the current PC as an integer.
  static int getVmPc() {
    return _getVmPc();
  }

  /// Calls the C++ function to step the VM by one instruction.
  static void stepVm() {
    _stepVm();
  }

  /// Calls the C++ function to reset the VM program.
  static void resetProgram() {
    _resetProgram();
  }

  // **修正：getVmAllRegisters 函数的实现**
  static List<int> getVmAllRegisters() {
    // C++ 返回的是 IntArray **值**，Dart FFI 也会将其映射为 IntArray 值。
    final IntArray cRegisters = _getVmAllRegisters();

    // 在 Dart 中，IntArray 是值类型，不能直接检查其是否为 nullptr。
    // 应该检查其内部的 data 指针是否为 nullptr。
    if (cRegisters.data == nullptr) {
      print(
        "[Dart] C++ returned an IntArray with a null data pointer for registers.",
      );
      return [];
    }

    try {
      // 调用 IntArray 扩展方法，将 C 数据复制到 Dart List<int>
      final List<int> registers = cRegisters.toDartInts();
      return registers;
    } finally {
      // 确保释放由 C++ 分配的 IntArray.data 内存
      _freeIntArrayData(cRegisters.data);
    }
  }
}
