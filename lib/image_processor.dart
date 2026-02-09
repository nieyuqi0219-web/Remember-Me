import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageProcessor {
  /// 裁剪任务
  /// 输入：原始图片数据，裁剪区域 [y_min, x_min, y_max, x_max] (0-1000 归一化坐标)
  /// 输出：裁剪后的图片数据
  static Future<Uint8List?> cropByCoordinates(
    Uint8List inputBytes,
    List<int> box2d, // [ymin, xmin, ymax, xmax]
  ) async {
    return compute(_cropTask, {'bytes': inputBytes, 'box': box2d});
  }

  // 后台裁剪任务
  static Uint8List? _cropTask(Map<String, dynamic> params) {
    try {
      final Uint8List inputBytes = params['bytes'];
      final List<int> box = params['box']; // [ymin, xmin, ymax, xmax]

      // 1. 解码图片
      final img.Image? original = img.decodeImage(inputBytes);
      if (original == null) return null;

      // 2. 将 0-1000 的坐标转换为实际像素坐标
      // box格式: [ymin, xmin, ymax, xmax]
      final int yMin = (box[0] / 1000 * original.height).toInt();
      final int xMin = (box[1] / 1000 * original.width).toInt();
      final int yMax = (box[2] / 1000 * original.height).toInt();
      final int xMax = (box[3] / 1000 * original.width).toInt();

      final int width = xMax - xMin;
      final int height = yMax - yMin;

      // 3. 校验边界
      if (width <= 0 || height <= 0) return null;

      // 4. 执行裁剪
      final img.Image cropped = img.copyCrop(original,
          x: xMin, y: yMin, width: width, height: height);

      // 5. 编码为 JPG 返回
      return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
    } catch (e) {
      debugPrint("裁剪出错: $e");
      return null;
    }
  }
}
