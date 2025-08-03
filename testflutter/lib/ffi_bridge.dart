import 'dart:ffi';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:ffi/ffi.dart'; // Make sure this is imported for Utf8 and other ffi utilities

// Define Dart 中的 StringArray 结构体，必须精确匹配 C++ 中的定义
// C++ struct:
// struct StringArray {
//   char** strings;
//   size_t count;
// };
// Using @IntSize() is correct for size_t on all platforms
final class StringArray extends Struct {
  external Pointer<Pointer<Char>> strings;

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

// --- FFI Function Type Definitions ---

// Define C++ function signature for getting hardcoded VM instructions
typedef GetHardcodedVmInstructionsC = Pointer<StringArray> Function();
typedef GetHardcodedVmInstructionsDart = Pointer<StringArray> Function();

// Define C++ free function signature (for memory management)
typedef FreeStringArrayC = Void Function(Pointer<StringArray> array);
typedef FreeStringArrayDart = void Function(Pointer<StringArray> array);

typedef GetVmPcC = IntPtr Function();
typedef GetVmPcDart = int Function();

/// A bridge to call native C++ functions for compiler operations.
class NativeCompilerBridge {
  static final DynamicLibrary _dylib = _openDynamicLibrary();

  // Helper to open the correct dynamic library based on platform
  static DynamicLibrary _openDynamicLibrary() {
    if (Platform.isWindows) {
      // In our CMake setup, DLLs go into `dll` folder relative to project root.
      // And the DLL name is `cpl_ffi_lib.dll`.
      return DynamicLibrary.open(
        p.join(Directory.current.path, 'dll', 'cpl_ffi_lib.dll'),
      );
    } else if (Platform.isMacOS) {
      // For macOS, the shared library name is typically `libcpl_ffi_lib.dylib`.
      return DynamicLibrary.open(
        p.join(Directory.current.path, 'lib', 'libcpl_ffi_lib.dylib'),
      );
    } else if (Platform.isLinux) {
      // For Linux, the shared library name is typically `libcpl_ffi_lib.so`.
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
      >(
        'get_hardcoded_vm_instructions',
      ); // Ensure this matches your C++ EXPORT_API function name

  static final _freeStringArray = _dylib
      .lookupFunction<FreeStringArrayC, FreeStringArrayDart>(
        'free_string_array',
      );

  static final _getVmPc = _dylib.lookupFunction<GetVmPcC, GetVmPcDart>(
    'get_vm_pc',
  );

  /// Calls the C++ function to retrieve the hardcoded VM instruction assembly code.
  ///
  /// It manages memory by automatically freeing the C++ allocated `StringArray`.
  static List<String> getHardcodedVmAssemblyCode() {
    final Pointer<StringArray> nativeArrayPtr = _getHardcodedVmInstructions();

    // Guard against null pointer returned from C++
    if (nativeArrayPtr == nullptr) {
      print(
        "[Dart] C++ returned a null StringArray pointer for hardcoded instructions.",
      );
      return [];
    }

    try {
      // Convert the C StringArray pointer to a Dart List<String>
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
}
