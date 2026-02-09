import 'dart:math';
import 'dart:typed_data'; // Needed for Uint8List
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'story_home_view.dart';
import 'memory_model.dart';
import 'home_page.dart';

// Data Model with Photos support
class ChatMessage {
  final String text;
  final bool isUser;
  final bool isSystem;
  final List<Uint8List>? relatedPhotos;

  ChatMessage(
      {required this.text,
      required this.isUser,
      this.isSystem = false,
      this.relatedPhotos});
}

// ✅✅✅ 核心修改 1：定义全局变量来存储聊天记录
// 放在类外面，这样页面销毁了它还在，只有 App 彻底关闭才会清空
List<ChatMessage> _globalChatHistory = [];

class ChatPage extends StatefulWidget {
  final List<StoryCollection> collections;
  final List<ChatMessage> chatHistory; // 保留这个参数是为了兼容 HomePage，但我们内部不再依赖它

  const ChatPage(
      {super.key, required this.collections, required this.chatHistory});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // ⚠️ 请确保这里填入了有效的 API Key
  final String _apiKey = 'YOUR_API_KEY_HERE';
  final String _modelName = 'gemini-3-flash-preview';

  late final GenerativeModel _model;
  late ChatSession _chatSession;

  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(model: _modelName, apiKey: _apiKey);
    _chatSession = _model.startChat();

    // ✅✅✅ 核心修改 2：只在全局历史为空时（第一次进入），才发欢迎语
    // 如果已经有记录了，就什么都不做，直接显示旧记录
    if (_globalChatHistory.isEmpty) {
      _addMessage(ChatMessage(
          text:
              "Hi! I'm your Memory Assistant. Ask me anything, like 'Where did my mom go in 1989?', and I'll find the photos for you.",
          isUser: false));
    } else {
      // 如果有历史记录，延迟滚动到底部
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    }
  }

  void _addMessage(ChatMessage msg) {
    setState(() {
      // ✅✅✅ 核心修改 3：把消息存入全局变量
      _globalChatHistory.add(msg);
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- Smart Search Logic ---
  List<StoryPhoto> _findRelevantPhotos(String query) {
    List<StoryPhoto> matched = [];
    final lowerQuery = query.toLowerCase();

    // 1. Keyword Match from Remarks
    for (var collection in widget.collections) {
      for (var photo in collection.photos) {
        if (photo.remark != null &&
            photo.remark!.toLowerCase().contains(lowerQuery)) {
          matched.add(photo);
        }
      }
    }

    // 2. Fallback strategy
    if (matched.isEmpty) {
      for (var collection in widget.collections) {
        if (collection.photos.isNotEmpty) {
          matched.add(collection.photos.first);
        }
      }
    }

    // Limit to 5 photos for speed
    return matched.take(5).toList();
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    _textCtrl.clear();
    _addMessage(ChatMessage(text: text, isUser: true));
    FocusScope.of(context).unfocus();

    setState(() => _isAnalyzing = true);

    try {
      final relevantPhotos = _findRelevantPhotos(text);
      List<Part> parts = [];

      parts.add(TextPart("""
        You are a Memory Assistant. The user asked: "$text".
        I have found ${relevantPhotos.length} photos that might be relevant.
        Please answer the user's question based on these photos.
        Be brief and warm. 
      """));

      for (var photo in relevantPhotos) {
        parts.add(DataPart('image/jpeg', photo.imageBytes));
        if (photo.remark != null) parts.add(TextPart("Note: ${photo.remark}"));
      }

      var response = await _chatSession.sendMessage(Content.multi(parts));

      if (response.text != null) {
        _addMessage(ChatMessage(
            text: response.text!,
            isUser: false,
            relatedPhotos: relevantPhotos.map((e) => e.imageBytes).toList()));
      }
    } catch (e) {
      _addMessage(ChatMessage(text: "Connection error: $e", isUser: false));
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  // 全屏查看图片
  void _showFullScreenImage(Uint8List imageBytes) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(imageBytes),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFFFDF8E4);
    const Color textColor = Color(0xFF5D4037);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textColor),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false,
            );
          },
        ),
        title: const Text("Memory Chat",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Chat Area
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              // ✅✅✅ 核心修改 4：渲染时使用全局变量
              itemCount: _globalChatHistory.length,
              itemBuilder: (context, index) {
                final msg = _globalChatHistory[index];
                return Align(
                  alignment:
                      msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: msg.isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      // Text Bubble
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color: msg.isSystem
                              ? Colors.transparent
                              : (msg.isUser
                                  ? const Color(0xFFFF8A65)
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: msg.isUser
                                ? const Radius.circular(0)
                                : const Radius.circular(16),
                            topLeft: !msg.isUser
                                ? const Radius.circular(0)
                                : const Radius.circular(16),
                          ),
                          boxShadow: msg.isSystem
                              ? []
                              : [
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2))
                                ],
                        ),
                        child: Text(
                          msg.text,
                          style: TextStyle(
                            color: msg.isSystem
                                ? Colors.grey
                                : (msg.isUser ? Colors.white : textColor),
                            fontSize: msg.isSystem ? 12 : 15,
                            fontStyle: msg.isSystem
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),

                      // Photo Grid
                      if (msg.relatedPhotos != null &&
                          msg.relatedPhotos!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12, top: 4),
                          constraints: const BoxConstraints(maxWidth: 280),
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: msg.relatedPhotos!.length,
                            itemBuilder: (context, imgIndex) {
                              final imgBytes = msg.relatedPhotos![imgIndex];
                              return GestureDetector(
                                onTap: () => _showFullScreenImage(imgBytes),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                        image: MemoryImage(imgBytes),
                                        fit: BoxFit.cover),
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black12, blurRadius: 2)
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                    ],
                  ),
                );
              },
            ),
          ),

          // Input Area
          if (_isAnalyzing)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Searching & Thinking...",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, -5))
                ]),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    decoration: InputDecoration(
                      hintText: "Ask about memories...",
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD54F),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send,
                        color: Color(0xFF5D4037), size: 20),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
