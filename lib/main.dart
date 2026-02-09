import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'welcome_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 🟢 核心修复：把这行代码加回来！
  // 因为你的手机没有 VPN 软件，必须通过代码告诉 App 去连电脑的代理
  HttpOverrides.global = _MyHttpOverrides();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RememberMe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.amber,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const WelcomePage(),
    );
  }
}

// 👇 这个类必须启用，因为 Flutter 不会自己读 Wi-Fi 里的代理设置
class _MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      // ⚠️⚠️⚠️ 重点：这里的 IP 和端口，必须和你手机 Wi-Fi 设置里填的一模一样！
      // 如果你今天电脑 IP 变了，这里也要改！
      ..findProxy = (uri) {
        return "PROXY 192.168.2.102:7897";
      }
      ..badCertificateCallback = (cert, host, port) => true;
  }
}
