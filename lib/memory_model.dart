import 'dart:typed_data';

// 1. 定义照片模型
class StoryPhoto {
  final String id;
  final Uint8List imageBytes;
  String remark; // 照片备注
  bool isFavorite; // ✅ 新增关键字段：是否加入 Timeline 精选

  StoryPhoto({
    required this.id,
    required this.imageBytes,
    this.remark = "", // 默认为空字符串，防止报错
    this.isFavorite = false, // ✅ 默认不选中
  });
}

// 2. 定义回忆集模型
class StoryCollection {
  final String id;
  String title;
  int year;
  List<StoryPhoto> photos;
  Uint8List? coverImageBytes;

  StoryCollection({
    required this.id,
    required this.title,
    required this.year,
    required this.photos,
    this.coverImageBytes,
  });
}

// 3. 全局数据源
List<StoryCollection> allStories = [
  // 预置数据
  StoryCollection(
    id: '1',
    title: "Grandpa's Days",
    year: 1989,
    photos: [],
    coverImageBytes: null,
  ),
  StoryCollection(
    id: '2',
    title: "My Graduation",
    year: 2015,
    photos: [],
    coverImageBytes: null,
  ),
  StoryCollection(
    id: '3',
    title: "First Job",
    year: 2018,
    photos: [],
    coverImageBytes: null,
  ),
];
