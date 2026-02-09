import 'package:flutter/material.dart';

// ✅ 这是一个纯内容页面，没有 Scaffold，没有 AppBar
// 这样嵌入到主页时，就不会出现“双重标题栏”了
class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 直接返回内容容器，背景色由外层 StoryHomeView 决定
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 图标容器
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.brown.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.hourglass_bottom_rounded,
              size: 60,
              color: Color(0xFF8D6E63),
            ),
          ),
          const SizedBox(height: 24),

          // 标题
          const Text(
            "Coming Soon",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // 温馨语录 (按你要求调整)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "May every sparkling moment of your life be remembered forever.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
                fontFamily: "Georgia",
              ),
            ),
          ),

          const SizedBox(height: 40),

          // 装饰点
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDot(4),
              _buildDot(6),
              _buildDot(4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDot(double size) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF8D6E63),
        shape: BoxShape.circle,
      ),
    );
  }
}
