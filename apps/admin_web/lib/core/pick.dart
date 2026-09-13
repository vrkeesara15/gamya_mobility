import 'package:file_picker/file_picker.dart';
import 'package:gamya_core/gamya_core.dart';

/// Opens the system file picker and returns the chosen files with their bytes loaded.
Future<List<UploadFile>> pickUploadFiles({FileType type = FileType.any, List<String>? extensions, bool multiple = false}) async {
  final picked = await FilePicker.pickFiles(type: type, allowedExtensions: extensions);
  final files = multiple ? picked : picked.take(1);
  final out = <UploadFile>[];
  for (final f in files) {
    out.add(UploadFile(name: f.name, bytes: await f.readAsBytes()));
  }
  return out;
}
