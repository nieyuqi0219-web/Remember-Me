import 'package:flutter/material.dart';
import 'home_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 配色方案
    const Color bgColor = Color(0xFFFDF8E4);
    const Color textColor = Color(0xFF5D4037);
    const Color buttonColor = Color(0xFFFFD54F);
    const Color sunColor = Color(0xFFFBC02D);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity, // 确保内容水平居中
          child: Column(
            children: [
              const SizedBox(height: 60),

              // --- 1. 顶部文字区域 (精准重叠版) ---
              // 使用 Column 也就是为了让下面 Someone & Something 居中
              Column(
                children: [
                  // 关键点：这个 Stack 只包裹 "Remember" 文字
                  // 这样 Positioned 的坐标就是相对于文字本身的
                  Stack(
                    clipBehavior: Clip.none, // 允许小太阳超出文字边界
                    alignment: Alignment.center,
                    children: [
                      // --- 文字层 ---
                      const Text(
                        "Remember",
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 40, // 字体稍微加大一点
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          height: 1.0,
                        ),
                      ),

                      // --- 左边的小太阳 (与 R 重叠) ---
                      Positioned(
                        left: -12, // 负数表示向左偏移，刚好压在 R 的左上角
                        top: -12,
                        child: Icon(Icons.wb_sunny_rounded,
                            color: sunColor, size: 28),
                      ),

                      // --- 右边的小太阳 (与 r 重叠) ---
                      Positioned(
                        right: -12, // 负数表示向右偏移，刚好压在 r 的右上角
                        top: -12,
                        child: Icon(Icons.wb_sunny_rounded,
                            color: sunColor, size: 28),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 下面的副标题
                  const Text(
                    "Someone & Something",
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // --- 中间插画区域 ---
              Container(
                constraints: const BoxConstraints(maxHeight: 350),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Image.asset(
                  'assets/welcome_illustration.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.image_not_supported,
                        size: 80, color: Colors.grey);
                  },
                ),
              ),

              const Spacer(flex: 1),

              // --- 2. 底部黄色按钮 (缩小版) ---
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HomePage()),
                  );
                },
                child: Container(
                  // ✅ 修改尺寸：从 260 改为 150，视觉上缩小一半
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: buttonColor,
                    borderRadius: BorderRadius.circular(35), // 圆角稍微减小一点以匹配尺寸
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 图标背景 (等比缩小)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.contacts_rounded,
                            size: 32, color: buttonColor), // 图标缩小
                      ),
                      const SizedBox(height: 12), // 间距缩小
                      // 按钮文字 (等比缩小)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            "MY Stories",
                            style: TextStyle(
                              fontSize: 16, // 文字缩小
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_circle_right,
                              color: textColor, size: 20), // 箭头缩小
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // --- 底部隐私条款 ---
              const Padding(
                padding: EdgeInsets.only(bottom: 20.0),
                child: Text(
                  "继续即视为同意我们的隐私政策与服务条款",
                  style: TextStyle(
                    fontSize: 11, // 稍微调小
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
