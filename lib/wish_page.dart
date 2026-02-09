import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'memory_model.dart'; // 引入数据源
import 'home_page.dart'; // 👈 ✅ 添加这一行

class WishPage extends StatefulWidget {
  const WishPage({super.key});

  @override
  State<WishPage> createState() => _WishPageState();
}

class _WishPageState extends State<WishPage> {
  // ⚠️ 务必填入你的 API Key
  final String _apiKey = 'YOUR_API_KEY_HERE';

  late final GenerativeModel _geminiModel;
  // Imagen 3 是目前生成写实人像效果最好的
  final String _imageModelName = 'imagen-4.0-generate-001';

  final TextEditingController _textCtrl = TextEditingController();

  // 状态变量
  bool _isGenerating = false;
  String _statusText = "";
  Uint8List? _generatedImage;
  String? _errorMessage;
  String? _optimizedPrompt;

  // ✅ 已选择的参考图
  final List<StoryPhoto> _selectedReferencePhotos = [];

  @override
  void initState() {
    super.initState();
    // 💡 借鉴 Nano Banana：为了达到更好的融合效果，这里建议尝试使用 'gemini-1.5-pro'
    // Pro 模型对图片的理解深度远高于 Flash，能更精准地捕捉人物神态。
    // 如果觉得慢，可以改回 'gemini-1.5-flash'
    _geminiModel =
        GenerativeModel(model: 'gemini-3-flash-preview', apiKey: _apiKey);
  }

  // 📸 选图逻辑 (保持不变，因为这比 React 的上传更方便)
  void _openPhotoSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.8,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Select Source Portraits", // 借鉴 React 的文案
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037))),
              ),
              Expanded(
                child: allStories.isEmpty
                    ? const Center(
                        child: Text("No albums yet.",
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: controller,
                        itemCount: allStories.length,
                        itemBuilder: (context, index) {
                          final album = allStories[index];
                          if (album.photos.isEmpty) return const SizedBox();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                child: Text(album.title,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[600],
                                        fontSize: 14)),
                              ),
                              SizedBox(
                                height: 110,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: album.photos.length,
                                  itemBuilder: (ctx, pIndex) {
                                    final photo = album.photos[pIndex];
                                    final isSelected = _selectedReferencePhotos
                                        .contains(photo);
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedReferencePhotos
                                                .remove(photo);
                                          } else {
                                            if (_selectedReferencePhotos
                                                    .length <
                                                2) {
                                              _selectedReferencePhotos
                                                  .add(photo);
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          "Max 2 portraits allowed.")));
                                            }
                                          }
                                        });
                                        Navigator.pop(context);
                                      },
                                      child: Container(
                                        width: 100,
                                        margin: const EdgeInsets.only(
                                            right: 12, bottom: 12),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: isSelected
                                              ? Border.all(
                                                  color: Colors.indigo,
                                                  width: 3)
                                              : null,
                                          image: DecorationImage(
                                              image:
                                                  MemoryImage(photo.imageBytes),
                                              fit: BoxFit.cover),
                                        ),
                                        child: isSelected
                                            ? const Center(
                                                child: Icon(Icons.check_circle,
                                                    color: Colors.white,
                                                    size: 30))
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                              )
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🧠 核心功能：复刻 Nano Banana 的 "Merge" 逻辑
  Future<void> _generateMagicImage() async {
    final userScene = _textCtrl.text.trim();
    if (userScene.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _generatedImage = null;
      _optimizedPrompt = null;
      _statusText = "Analyzing portraits & scene..."; // 状态 1
    });

    try {
      // 1. 构造发给 Gemini 的请求
      // 我们模拟 React 代码里的 mergeImages(img1, img2, scene)
      List<Part> inputs = [];

      // 添加提示词：这是最关键的一步，我们借鉴了 AI Studio 高级合成的 Prompt 结构
      String promptText = """
      You are an expert Image Compositor and Prompt Engineer.
      
      I will provide you with:
      1. ${_selectedReferencePhotos.length} reference portrait(s).
      2. A desired scene description: "$userScene".
      
      YOUR TASK:
      Write a highly detailed image generation prompt for Imagen 3 that MERGES these specific people into the requested scene naturally.
      
      CRITICAL REQUIREMENTS:
      - **Identity Preservation**: Analyze the uploaded faces (eye shape, nose, hair texture, age, ethnicity) and describe them explicitly in the final prompt so the generated characters look like them.
      - **Scene Integration**: Do not just paste them in. Describe how the lighting of the "$userScene" affects their faces. Describe their pose and interaction to fit the scene perfectly.
      - **Style**: Photorealistic, 8k resolution, cinematic lighting, sharp focus.
      - **Clothing**: If the user didn't specify clothes, dress them appropriately for the scene.
      
      Output ONLY the final prompt string. No introduction.
      """;

      inputs.add(TextPart(promptText));

      // 添加图片数据
      for (var photo in _selectedReferencePhotos) {
        inputs.add(DataPart('image/jpeg', photo.imageBytes));
      }

      // 2. 发送给 Gemini 进行 "多模态融合思考"
      final textResponse =
          await _geminiModel.generateContent([Content.multi(inputs)]);
      final betterPrompt = textResponse.text ?? userScene;

      setState(() {
        _optimizedPrompt = betterPrompt;
        _statusText = "Rendering masterpiece..."; // 状态 2
      });

      debugPrint("✨ Merged Prompt: $betterPrompt");

      // 3. 调用 Imagen 生成 (这一步和之前一样，因为这是目前生成图片的标准接口)
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$_imageModelName:predict?key=$_apiKey');

      final Map<String, dynamic> requestBody = {
        "instances": [
          {"prompt": betterPrompt}
        ],
        "parameters": {
          "sampleCount": 1,
          "aspectRatio": "3:4", // 改为 3:4 竖屏比例，更适合人像合成
          "includeRaiReason": true
        }
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['predictions'] != null &&
            (data['predictions'] as List).isNotEmpty) {
          final String base64Image =
              data['predictions'][0]['bytesBase64Encoded'];
          setState(() {
            _generatedImage = base64Decode(base64Image);
            _statusText = "";
          });
        } else {
          throw "No image data returned. (Check safety filters)";
        }
      } else {
        throw "Server Error: ${response.statusCode}";
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
      setState(() {
        _errorMessage = "Merge failed. Try again.\n$e";
      });
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // 保存图片
  Future<void> _saveImage(Uint8List bytes, BuildContext context) async {
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) await Gal.requestAccess();
      await Gal.putImageBytes(bytes,
          name: "PersonaLink_${DateTime.now().millisecondsSinceEpoch}");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("✅ Saved to Gallery!"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      // ignore
    }
  }

  // 全屏查看
  void _showFullImage(BuildContext context, Uint8List imageBytes) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(imageBytes, fit: BoxFit.contain),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Positioned(
                bottom: 40,
                child: ElevatedButton.icon(
                  onPressed: () => _saveImage(imageBytes, context),
                  icon: const Icon(Icons.download),
                  label: const Text("Save Masterpiece"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.indigo,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFFFDF8E4);
    const Color textColor = Color(0xFF5D4037);

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        // 👇👇👇 ✅ 开始插入：添加返回按钮
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () {
            // 销毁当前页面，重置到 HomePage (默认显示主题回忆集)
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false,
            );
          },
        ),
        // 👆👆👆 ✅ 结束插入
        title: const Text("Memories Weaver", // 致敬 Nano Banana 的名字
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. 内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildContentArea(textColor),

                    // ✨ 显示选中的参考图
                    if (_selectedReferencePhotos.isNotEmpty &&
                        !_isGenerating &&
                        _generatedImage == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Column(
                          children: [
                            Text("Merging these people:",
                                style: TextStyle(
                                    color: textColor.withOpacity(0.6),
                                    fontSize: 12)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _selectedReferencePhotos
                                  .map((p) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5),
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.memory(p.imageBytes,
                                                  width: 70,
                                                  height: 70,
                                                  fit: BoxFit.cover),
                                            ),
                                            Positioned(
                                              right: 0,
                                              top: 0,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedReferencePhotos
                                                        .remove(p);
                                                  });
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(2),
                                                  decoration:
                                                      const BoxDecoration(
                                                          color: Colors.white,
                                                          shape:
                                                              BoxShape.circle),
                                                  child: const Icon(Icons.close,
                                                      size: 14,
                                                      color: Colors.black),
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),

                    // ✨ 显示优化后的 Prompt
                    if (_optimizedPrompt != null &&
                        !_isGenerating &&
                        _generatedImage != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.indigo.withOpacity(0.2))),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome,
                                    size: 16, color: Colors.indigo),
                                SizedBox(width: 8),
                                Text("Generated Scene Prompt",
                                    style: TextStyle(
                                        color: Colors.indigo,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _optimizedPrompt!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: textColor.withOpacity(0.8),
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ),

            // 2. 底部输入区
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -5))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isGenerating)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: TextButton.icon(
                        onPressed: _openPhotoSelector,
                        icon: const Icon(Icons.add_a_photo, size: 18),
                        label: Text(_selectedReferencePhotos.isEmpty
                            ? "Add Source Portraits"
                            : "Source Portraits (${_selectedReferencePhotos.length}/2)"),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.indigo,
                            backgroundColor: Colors.indigo.withOpacity(0.1),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8)),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          enabled: !_isGenerating,
                          decoration: InputDecoration(
                            // 借鉴 React 的 placeholder
                            hintText: "E.g., A cozy modern coffee shop...",
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _generateMagicImage(),
                        ),
                      ),
                      GestureDetector(
                        onTap: _isGenerating ? null : _generateMagicImage,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: _isGenerating
                                ? null
                                : const LinearGradient(colors: [
                                    Color(0xFF5C6BC0),
                                    Color(0xFF3949AB)
                                  ]), // 使用 Indigo 色系致敬
                            color: _isGenerating ? Colors.grey[300] : null,
                            shape: BoxShape.circle,
                          ),
                          child: _isGenerating
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.auto_fix_high,
                                  color: Colors.white, size: 24),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildContentArea(Color textColor) {
    if (_isGenerating) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 200,
            width: 200,
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.indigo.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5)
                ]),
            child: const Center(
                child: CircularProgressIndicator(color: Colors.indigo)),
          ),
          const SizedBox(height: 32),
          Text(_statusText,
              style: TextStyle(
                  color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      );
    }
    if (_errorMessage != null) {
      return Column(children: [
        const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
        const SizedBox(height: 16),
        Text(_errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 12)),
      ]);
    }
    if (_generatedImage != null) {
      return GestureDetector(
        onTap: () => _showFullImage(context, _generatedImage!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.memory(_generatedImage!, fit: BoxFit.contain),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.diversity_1_rounded,
            size: 100, color: textColor.withOpacity(0.2)),
        const SizedBox(height: 24),
        Text("I Wish",
            style: TextStyle(
                color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "Select portraits, choose a scene, and let Gemini merge them into a new reality.",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: textColor.withOpacity(0.6), fontSize: 15, height: 1.5),
          ),
        ),
      ],
    );
  }
}
