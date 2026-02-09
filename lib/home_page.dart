import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'story_home_view.dart';
import 'timeline_page.dart';
// 如果你没有 chat_page.dart 或 wish_page.dart，请注释掉下面这两行，并把 _pages 里的对应页面换成 Placeholder()
import 'chat_page.dart';
import 'wish_page.dart';
import 'smart_scanner_page.dart';
import 'memory_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // 页面列表
  List<Widget> get _pages => [
        const StoryHomeView(), // 0: 只有网格内容
        const TimelinePage(), // 1: Timeline
        // 如果没有 ChatPage，可以用 const Center(child: Text("Chat Coming Soon")) 代替
        ChatPage(collections: allStories, chatHistory: []),
        // 如果没有 WishPage，可以用 const Center(child: Text("Wish Coming Soon")) 代替
        const WishPage(),
      ];

  final Color _primaryColor = const Color(0xFF5D4037);
  final Color _backgroundColor = const Color(0xFFFDF8E4);

  // ✅ 核心功能：跳转新建，并在回来时刷新
  void _handleCreateStory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SmartScannerPage()),
    );

    // 如果返回 true，说明新建了相册，强制刷新页面
    if (result == true) {
      setState(() {
        // 这会触发 HomePage 重绘，进而重绘 StoryHomeView，显示新相册
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
    ));

    return Scaffold(
      backgroundColor: _backgroundColor,

      // ✅ 唯一的 AppBar (只在第一个 Tab "Stories" 显示)
      appBar: _currentIndex == 0
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              centerTitle: false,
              title: Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                child: Text(
                  "My Stories",
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              actions: [
                // ✅ 右上角的加号：集成“新建+刷新”功能
                Padding(
                  padding: const EdgeInsets.only(right: 16.0, top: 8.0),
                  child: IconButton(
                    icon: Icon(Icons.add, color: _primaryColor, size: 32),
                    tooltip: "Add Story",
                    onPressed: _handleCreateStory, // 调用上面的方法
                  ),
                ),
              ],
            )
          : null,

      // 页面内容
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      // 唯一的底部导航栏
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: const Offset(0, -5))
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: Colors.white,
            selectedItemColor: _primaryColor,
            unselectedItemColor: Colors.grey[400],
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.grid_view_rounded), label: 'Stories'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.access_time_rounded), label: 'Timeline'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Chat'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.auto_awesome_outlined), label: 'Wish'),
            ],
          ),
        ),
      ),
    );
  }
}
