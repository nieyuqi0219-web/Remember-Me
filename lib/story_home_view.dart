import 'package:flutter/material.dart';
import 'album_detail_page.dart';
import 'memory_model.dart';

// ✅ 这是一个纯内容组件，不再是页面框架
// 它的外层由 HomePage 的 Scaffold 包裹，所以不会出现双重标题
class StoryHomeView extends StatefulWidget {
  const StoryHomeView({super.key});

  @override
  State<StoryHomeView> createState() => _StoryHomeViewState();
}

class _StoryHomeViewState extends State<StoryHomeView> {
  final List<Color> _cardColors = [
    const Color(0xFFEFEBE9),
    const Color(0xFFE0F2F1),
    const Color(0xFFF3E5F5),
    const Color(0xFFFFF3E0),
    const Color(0xFFECEFF1),
  ];

  Color _getThemeColor(int index) {
    return _cardColors[index % _cardColors.length];
  }

  // 长按编辑弹窗
  void _showEditDialog(StoryCollection item) {
    final titleCtrl = TextEditingController(text: item.title);
    final yearCtrl = TextEditingController(text: item.year.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Story Info"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: "Event / Title")),
            TextField(
                controller: yearCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Year")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                int index = allStories.indexOf(item);
                if (index != -1) {
                  allStories[index] = StoryCollection(
                    id: item.id,
                    title: titleCtrl.text,
                    year: int.tryParse(yearCtrl.text) ?? item.year,
                    photos: item.photos,
                    coverImageBytes: item.coverImageBytes,
                  );
                }
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ❌ 不再返回 Scaffold，只返回内容
    // 这样它就完美融入了 HomePage 的 body 里
    if (allStories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No stories yet.\nTap + on top right to create!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: allStories.length,
      itemBuilder: (context, index) {
        final item = allStories[index];
        final themeColor = _getThemeColor(index);

        return GestureDetector(
          onTap: () {
            // 点击跳转详情页
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => AlbumDetailPage(collection: item)),
            ).then((_) {
              // 从详情页回来时刷新
              setState(() {});
            });
          },
          onLongPress: () => _showEditDialog(item),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 65,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    child: item.coverImageBytes != null
                        ? Image.memory(item.coverImageBytes!, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, color: Colors.grey)),
                  ),
                ),
                Expanded(
                  flex: 35,
                  child: Container(
                    decoration: BoxDecoration(
                      color: themeColor,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("${item.year}",
                            style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF4E342E),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                height: 1.2)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
