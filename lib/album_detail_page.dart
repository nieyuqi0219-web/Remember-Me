import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;
import 'memory_model.dart';

class AlbumDetailPage extends StatefulWidget {
  final StoryCollection collection;
  const AlbumDetailPage({super.key, required this.collection});
  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  // ⚠️ 务必填入你的 API Key
  final String _apiKey = 'AIzaSyDouJ-7zIpQKXMoTrt-qXqDxpHyNPL7Qlw';

  final ImagePicker _picker = ImagePicker();
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  // 🔥🔥🔥 新增：实时获取全局最新的数据对象 (Timeline 同步的关键) 🔥🔥🔥
  StoryCollection get _liveCollection {
    try {
      return allStories.firstWhere((c) => c.id == widget.collection.id);
    } catch (e) {
      return widget.collection;
    }
  }

  // 普通添加
  Future<void> _addPhotosRegular(ImageSource source) async {
    try {
      List<XFile> images = [];
      if (source == ImageSource.gallery) {
        images = await _picker.pickMultiImage(
            maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      } else {
        final XFile? photo = await _picker.pickImage(
            source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
        if (photo != null) images.add(photo);
      }
      _saveImagesToMemory(images);
    } catch (e) {
      debugPrint("Add error: $e");
    }
  }

  // ==========================================
  // ⚡ AI 智能分割 (完全保持你原本能用的代码)
  // ==========================================
  Future<void> _scanAndAutoSplit(ImageSource source) async {
    final XFile? pagePhoto = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (pagePhoto == null) return;
    _showLoadingDialog("正在读取图片...");

    try {
      final Uint8List pageBytes = await pagePhoto.readAsBytes();
      _updateLoadingText("AI 正在分析布局..."); // Gemini 3

      final model =
          GenerativeModel(model: 'gemini-3-flash-preview', apiKey: _apiKey);

      final prompt = TextPart("""
      Return a bounding box for each photo in this image. 
      Output a JSON object with a key "boxes" containing a list of [ymin, xmin, ymax, xmax] coordinates.
      Coordinates must be scaled 0-1000. 
      Example: {"boxes": [[0, 0, 500, 500]]}
      JSON ONLY. No Markdown.
      """);

      final content =
          Content.multi([prompt, DataPart('image/jpeg', pageBytes)]);
      final response = await model.generateContent([content]);
      String? jsonText = response.text;

      if (jsonText != null) {
        jsonText = jsonText.replaceAll(RegExp(r'```json|```'), '').trim();
        final startIndex = jsonText.indexOf('{');
        final endIndex = jsonText.lastIndexOf('}') + 1;
        if (startIndex != -1 && endIndex != -1) {
          jsonText = jsonText.substring(startIndex, endIndex);
        }

        Map<String, dynamic> data = jsonDecode(jsonText);
        List<dynamic> boxes = data['boxes'] ?? [];

        if (boxes.isEmpty) throw "AI 未检测到任何照片";

        _updateLoadingText("正在裁剪 ${boxes.length} 张照片...");

        final List<Uint8List> results =
            await compute(_isolateCropTask, CropData(pageBytes, boxes));

        Navigator.of(context).pop();

        if (results.isNotEmpty) {
          _saveBytesToMemory(results, "AI Split");
          _showResultDialog("成功", "已提取 ${results.length} 张照片");
        } else {
          throw "裁剪结果为空";
        }
      } else {
        throw "AI 返回为空";
      }
    } catch (e) {
      Navigator.of(context).pop();
      String errorMsg = e.toString();
      if (errorMsg.contains("Connection reset") ||
          errorMsg.contains("SocketException")) {
        errorMsg += "\n\n💡 提示：App 现在直接使用手机网络，请确保手机 VPN 已开启且能上 Google。";
      }
      _showErrorDialog("AI 错误", errorMsg);
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
              const CircularProgressIndicator(color: Colors.orangeAccent),
              const SizedBox(width: 20),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  }

  void _updateLoadingText(String text) {
    if (Navigator.canPop(context)) Navigator.of(context).pop();
    _showLoadingDialog(text);
  }

  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
        ],
      ),
    );
  }

  void _showResultDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
        ],
      ),
    );
  }

  void _saveImagesToMemory(List<XFile> images) async {
    for (var img in images) {
      final bytes = await img.readAsBytes();
      _addPhotoObject(bytes, "");
    }
  }

  void _saveBytesToMemory(List<Uint8List> imagesBytes, String remark) {
    for (var bytes in imagesBytes) {
      _addPhotoObject(bytes, remark);
    }
  }

  // ✅ 修改点 1：添加照片时，必须添加到 _liveCollection (全局变量)
  // 否则 Timeline 读不到新照片
  void _addPhotoObject(Uint8List bytes, String remark) {
    final newPhoto = StoryPhoto(
      id: DateTime.now().microsecondsSinceEpoch.toString() +
          (DateTime.now().millisecond).toString(),
      imageBytes: bytes,
      remark: remark,
      isFavorite: false,
    );

    setState(() {
      // 操作 _liveCollection 而不是 widget.collection
      _liveCollection.photos.insert(0, newPhoto);
      if (_liveCollection.coverImageBytes == null) {
        _liveCollection.coverImageBytes = bytes;
      }
    });
  }

  // ✅ 修改点 2：点星星时，必须同步到 _liveCollection
  void _toggleFavorite() {
    if (_selectedIds.isEmpty) return;
    setState(() {
      // 遍历全局列表
      for (var photo in _liveCollection.photos) {
        if (_selectedIds.contains(photo.id)) {
          // 修改全局状态
          photo.isFavorite = !photo.isFavorite;
        }
      }
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Updated! ⭐")));
  }

  // ✅ 修改点 3：删除时同步
  void _deleteSelected() {
    if (_selectedIds.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Photos"),
        content: Text("Delete ${_selectedIds.length} photos?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              setState(() {
                _liveCollection.photos
                    .removeWhere((p) => _selectedIds.contains(p.id));

                if (_liveCollection.photos.isEmpty) {
                  _liveCollection.coverImageBytes = null;
                } else {
                  _liveCollection.coverImageBytes =
                      _liveCollection.photos.first.imageBytes;
                }

                _selectedIds.clear();
                _isSelectionMode = false;
              });
              Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(int initialIndex) {
    showDialog(
      context: context,
      useSafeArea: false,
      // 看大图也用 _liveCollection
      builder: (context) => _FullScreenViewer(
          photos: _liveCollection.photos, initialIndex: initialIndex),
    );
  }

  void _showAISourceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("AI Scan Source"),
        content: const Text("Use AI to split a full album page?"),
        actions: [
          TextButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text("Gallery"),
              onPressed: () {
                Navigator.pop(ctx);
                _scanAndAutoSplit(ImageSource.gallery);
              }),
          ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text("Camera"),
              onPressed: () {
                Navigator.pop(ctx);
                _scanAndAutoSplit(ImageSource.camera);
              }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 界面使用 _liveCollection 渲染
    final currentData = _liveCollection;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8E4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          color: const Color(0xFF5D4037),
          onPressed: () => _isSelectionMode
              ? setState(() => _isSelectionMode = false)
              : Navigator.pop(context),
        ),
        title: Text(
            _isSelectionMode
                ? "${_selectedIds.length} Selected"
                : currentData.title,
            style: const TextStyle(
                color: Color(0xFF5D4037), fontWeight: FontWeight.bold)),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
                icon: const Icon(Icons.star, color: Colors.orange),
                onPressed: _toggleFavorite),
            IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: _deleteSelected),
            IconButton(
                icon: const Icon(Icons.check, color: Color(0xFF5D4037)),
                onPressed: () => setState(() => _isSelectionMode = false)),
          ] else ...[
            IconButton(
                icon: const Icon(Icons.checklist, color: Color(0xFF5D4037)),
                onPressed: () => setState(() => _isSelectionMode = true)),
          ]
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 30.0),
        child: SizedBox(
          width: 70,
          height: 70,
          child: FloatingActionButton(
            backgroundColor: Colors.orangeAccent,
            elevation: 8,
            shape: const CircleBorder(),
            child: const Icon(Icons.add, color: Colors.white, size: 36),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20))),
                builder: (ctx) => SafeArea(
                  child: Wrap(
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                              child: Text("Add Memories",
                                  style: TextStyle(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.bold)))),
                      ListTile(
                        leading: const Icon(Icons.auto_fix_high,
                            color: Colors.purple, size: 28),
                        title: const Text("AI Scan (Auto Split)",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showAISourceDialog();
                        },
                      ),
                      const Divider(),
                      ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text("Import from Gallery"),
                          onTap: () {
                            Navigator.pop(ctx);
                            _addPhotosRegular(ImageSource.gallery);
                          }),
                      ListTile(
                          leading: const Icon(Icons.camera_alt),
                          title: const Text("Take Photo"),
                          onTap: () {
                            Navigator.pop(ctx);
                            _addPhotosRegular(ImageSource.camera);
                          }),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      body: currentData.photos.isEmpty
          ? Center(
              child: Text("Tap + to add memories",
                  style: TextStyle(color: Colors.grey[400])))
          : _buildWaterfallList(currentData),
    );
  }

  Widget _buildWaterfallList(StoryCollection currentData) {
    final List<StoryPhoto> left = [];
    final List<StoryPhoto> right = [];
    for (int i = 0; i < currentData.photos.length; i++) {
      if (i % 2 == 0)
        left.add(currentData.photos[i]);
      else
        right.add(currentData.photos[i]);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Column(
                  children: left
                      .map((p) => _buildPhotoItem(p, currentData.photos))
                      .toList())),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  children: right
                      .map((p) => _buildPhotoItem(p, currentData.photos))
                      .toList())),
        ],
      ),
    );
  }

  Widget _buildPhotoItem(StoryPhoto photo, List<StoryPhoto> allPhotos) {
    final originalIndex = allPhotos.indexOf(photo);
    final isSelected = _selectedIds.contains(photo.id);
    return GestureDetector(
      onTap: () => _isSelectionMode
          ? setState(() => isSelected
              ? _selectedIds.remove(photo.id)
              : _selectedIds.add(photo.id))
          : _showFullScreenImage(originalIndex),
      onLongPress: () => setState(() {
        _isSelectionMode = true;
        _selectedIds.add(photo.id);
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: Colors.orangeAccent, width: 3)
              : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.memory(photo.imageBytes, fit: BoxFit.fitWidth),
              if (photo.isFavorite)
                Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.star,
                            color: Colors.orange, size: 18))),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullScreenViewer extends StatelessWidget {
  final List<StoryPhoto> photos;
  final int initialIndex;
  const _FullScreenViewer({required this.photos, required this.initialIndex});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
              itemCount: photos.length,
              controller: PageController(initialPage: initialIndex),
              itemBuilder: (context, index) => InteractiveViewer(
                  child: Center(
                      child: Image.memory(photos[index].imageBytes,
                          fit: BoxFit.contain)))),
          Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context))),
        ],
      ),
    );
  }
}

// 后台裁剪任务 (完全未改动)
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
    if (w > 50 && h > 50) {
      final cropped =
          img.copyCrop(originalImage, x: x, y: y, width: w, height: h);
      results.add(Uint8List.fromList(img.encodeJpg(cropped)));
    }
  }
  return results;
}
