import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // 必须引入
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;
import 'memory_model.dart';

class SmartScannerPage extends StatefulWidget {
  const SmartScannerPage({super.key});

  @override
  State<SmartScannerPage> createState() => _SmartScannerPageState();
}

class _SmartScannerPageState extends State<SmartScannerPage> {
  // ⚠️ 请确认 API Key
  final String _apiKey = 'YOUR_API_KEY_HERE';

  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> _scannedImages = [];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();

  // 普通多选
  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
    if (images.isNotEmpty) {
      for (var img in images) {
        final bytes = await img.readAsBytes();
        setState(() => _scannedImages.add(bytes));
      }
    }
  }

  // ==========================================
  // ⚡ AI 智能分割 (正式稳定版)
  // ==========================================
  Future<void> _scanAndAutoSplit(ImageSource source) async {
    // 1. 选图 (保持压缩，这是成功的关键)
    final XFile? pagePhoto = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (pagePhoto == null) return;

    // 2. 显示正式的 Loading 弹窗
    _showLoadingDialog("正在读取图片...");

    try {
      final Uint8List pageBytes = await pagePhoto.readAsBytes();

      _updateLoadingText("AI 正在识别照片轮廓...");

      // ✅ 使用最稳的 1.5 flash
      final model =
          GenerativeModel(model: 'gemini-3-flash-preview', apiKey: _apiKey);

      final prompt = TextPart("""
      Return a bounding box for each photo in this image. 
      Output a JSON object with a key "boxes" containing a list of [ymin, xmin, ymax, xmax] coordinates.
      Coordinates must be scaled 0-1000. 
      Example: {"boxes": [[0, 0, 500, 500]]}
      JSON ONLY. No Markdown.
      """);

      final imagePart = DataPart('image/jpeg', pageBytes);
      final content = Content.multi([prompt, imagePart]);

      final response = await model.generateContent([content]);
      String? jsonText = response.text;

      if (jsonText != null) {
        // 清洗 JSON
        jsonText = jsonText.replaceAll(RegExp(r'```json|```'), '').trim();
        final startIndex = jsonText.indexOf('{');
        final endIndex = jsonText.lastIndexOf('}') + 1;
        if (startIndex != -1 && endIndex != -1) {
          jsonText = jsonText.substring(startIndex, endIndex);
        }

        Map<String, dynamic> data = jsonDecode(jsonText);
        List<dynamic> boxes = data['boxes'] ?? [];

        if (boxes.isEmpty) throw "AI 未检测到任何照片";

        _updateLoadingText("正在后台裁剪 ${boxes.length} 张照片...");

        // ✅ 后台裁剪 (防止卡死)
        final List<Uint8List> results =
            await compute(_isolateCropTask, CropData(pageBytes, boxes));

        Navigator.of(context).pop(); // 关闭弹窗

        // 将结果添加到预览区
        setState(() {
          _scannedImages.addAll(results);
        });

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("成功提取 ${results.length} 张照片")));
      } else {
        throw "AI 返回为空";
      }
    } catch (e) {
      Navigator.of(context).pop(); // 关闭弹窗
      _showErrorDialog(e.toString());
    }
  }

  // --- UI 工具 ---
  void _showLoadingDialog(String text) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          content: Row(
            children: [
              const CircularProgressIndicator(color: Colors.purple),
              const SizedBox(width: 20),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  }

  void _updateLoadingText(String text) {
    // 关闭当前的，开一个新的 (最稳妥的更新方式)
    if (Navigator.canPop(context)) Navigator.of(context).pop();
    _showLoadingDialog(text);
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("出错了"),
        content: Text(error),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
        ],
      ),
    );
  }

  void _saveCollection() {
    if (_scannedImages.isEmpty || _titleController.text.isEmpty) return;

    List<StoryPhoto> newPhotos = _scannedImages.map((bytes) {
      return StoryPhoto(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        imageBytes: bytes,
        remark: "Scanned",
        isFavorite: false,
      );
    }).toList();

    StoryCollection newCollection = StoryCollection(
      id: "scan_${DateTime.now().millisecondsSinceEpoch}",
      title: _titleController.text,
      year: int.tryParse(_yearController.text) ?? 2024,
      photos: newPhotos,
      coverImageBytes: newPhotos.isNotEmpty ? newPhotos.first.imageBytes : null,
    );

    allStories.add(newCollection);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8E4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF5D4037)),
        title: const Text("New Story",
            style: TextStyle(
                color: Color(0xFF5D4037), fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                    labelText: "Title", filled: true, fillColor: Colors.white)),
            const SizedBox(height: 12),
            TextField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: "Year", filled: true, fillColor: Colors.white)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text("AI Auto Split"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () => _showSourceDialog(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text("Select Multi"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: _pickImages,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _scannedImages.isEmpty
                ? Container(
                    height: 150,
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Text("No photos yet"),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8),
                    itemCount: _scannedImages.length,
                    itemBuilder: (context, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_scannedImages[index],
                          fit: BoxFit.cover),
                    ),
                  ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _scannedImages.isEmpty ? null : _saveCollection,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D4037),
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text("Create Story",
                    style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSourceDialog(bool isAI) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAI ? "AI Scan Source" : "Select Source"),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                isAI ? _scanAndAutoSplit(ImageSource.gallery) : _pickImages();
              },
              child: const Text("Gallery")),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                isAI ? _scanAndAutoSplit(ImageSource.camera) : _pickImages();
              },
              child: const Text("Camera")),
        ],
      ),
    );
  }
}

// ------------------------------------------------
// 🧵 后台裁剪任务 (必须是顶层函数)
// ------------------------------------------------
class CropData {
  final Uint8List imageBytes;
  final List<dynamic> boxes;
  CropData(this.imageBytes, this.boxes);
}

Future<List<Uint8List>> _isolateCropTask(CropData data) async {
  final originalImage = img.decodeImage(data.imageBytes);
  if (originalImage == null) return [];
  List<Uint8List> results = [];

  for (var box in data.boxes) {
    if (box.length < 4) continue;
    final rawYmin = box[0] as num;
    final rawXmin = box[1] as num;
    final rawYmax = box[2] as num;
    final rawXmax = box[3] as num;

    int x = ((rawXmin / 1000) * originalImage.width).toInt();
    int y = ((rawYmin / 1000) * originalImage.height).toInt();
    int w = (((rawXmax - rawXmin) / 1000) * originalImage.width).toInt();
    int h = (((rawYmax - rawYmin) / 1000) * originalImage.height).toInt();

    if (x < 0) x = 0;
    if (y < 0) y = 0;
    if (x + w > originalImage.width) w = originalImage.width - x;
    if (y + h > originalImage.height) h = originalImage.height - y;

    // 过滤太小的碎片
    if (w > 50 && h > 50) {
      final cropped =
          img.copyCrop(originalImage, x: x, y: y, width: w, height: h);
      results.add(Uint8List.fromList(img.encodeJpg(cropped)));
    }
  }
  return results;
}
