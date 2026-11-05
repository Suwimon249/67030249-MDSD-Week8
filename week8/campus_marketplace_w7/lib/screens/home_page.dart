import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/cart_model.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/favorites_repository_drift.dart';
import '../repositories/item_repository.dart';
import '../services/user_items_storage.dart';
import 'checkout_page.dart';
import '../services/gemini_service.dart';

class HomePage extends StatefulWidget {
  final ItemRepository repository;
  final FavoritesRepository favoritesRepository;
  final List<Item> userItems; // รายการสินค้าที่ผู้ใช้ลงประกาศขายใหม่

  const HomePage({
    super.key,
    required this.repository,
    required this.favoritesRepository,
    this.userItems = const [],
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Item>> _itemsFuture;
  final Set<int> _favoriteItemIds = {};

  @override
  void initState() {
    super.initState();
    _itemsFuture = widget.repository.getItems();
    // โหลดรายการสินค้าที่เคยบันทึกไว้ในรายการโปรด
    _loadFavorites();
    // ฟังการแจ้งเตือนเมื่อมีการเปลี่ยนแปลงรายการโปรด
    FavoritesRepositoryDrift.updateNotifier.addListener(_loadFavorites);
    // โหลดรายการสินค้าที่ผู้ใช้เคยลงขายไว้จากไฟล์ถาวร
    UserItemsStorage.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    FavoritesRepositoryDrift.updateNotifier.removeListener(_loadFavorites);
    super.dispose();
  }

  // โหลดรหัสสินค้าที่อยู่ในรายการโปรดเพื่อแสดงไอคอนหัวใจสีแดงค้างไว้
  Future<void> _loadFavorites() async {
    try {
      final favs = await widget.favoritesRepository.getAllFavorites();
      if (mounted) {
        setState(() {
          _favoriteItemIds.clear();
          _favoriteItemIds.addAll(favs.map((e) => e.itemId));
        });
      }
    } catch (_) {}
  }

  // ฟังก์ชันรีเฟรชหน้าจอ (ดึงข้อมูลใหม่โดยไม่ทำสินค้าที่ลงขายหาย)
  Future<void> _refresh() async {
    await UserItemsStorage.load();
    await _loadFavorites();
    if (mounted) {
      setState(() {
        _itemsFuture = widget.repository.getItems();
      });
    }
  }

  // หน้าต่างแก้ไขข้อมูลสินค้าและลบสินค้า
  void _openEditItem(Item item) {
    final titleCtrl = TextEditingController(text: item.title);
    final categoryCtrl = TextEditingController(text: item.category);
    final priceCtrl = TextEditingController(
      text: item.price > 0 ? item.price.toStringAsFixed(0) : '',
    );
    final descCtrl = TextEditingController(text: item.description);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'แก้ไขข้อมูลสินค้า',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: _buildItemImage(item.imageUrl),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อสินค้า',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'หมวดหมู่สินค้า',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ราคา (บาท)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'คำบรรยายสินค้า',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.delete),
                        label: const Text('ลบสินค้า'),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await UserItemsStorage.remove(item.id);
                          widget.userItems.removeWhere((i) => i.id == item.id);
                          try {
                            await widget.favoritesRepository.removeFavorite(item.id);
                          } catch (_) {}
                          await _refresh();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('ลบ "${item.title}" เรียบร้อยแล้ว'),
                                backgroundColor: Colors.red[700],
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('บันทึกการแก้ไข'),
                        onPressed: () async {
                          final newTitle = titleCtrl.text.trim();
                          if (newTitle.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('กรุณากรอกชื่อสินค้า')),
                            );
                            return;
                          }
                          final newPrice = double.tryParse(priceCtrl.text.trim()) ?? item.price;
                          final updated = Item(
                            id: item.id,
                            title: newTitle,
                            price: newPrice,
                            description: descCtrl.text.trim(),
                            category: categoryCtrl.text.trim().isNotEmpty
                                ? categoryCtrl.text.trim()
                                : item.category,
                            imageUrl: item.imageUrl,
                          );

                          Navigator.pop(ctx);
                          await UserItemsStorage.update(updated);
                          final uIdx = widget.userItems.indexWhere((i) => i.id == item.id);
                          if (uIdx != -1) {
                            widget.userItems[uIdx] = updated;
                          }
                          await _refresh();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('บันทึกการแก้ไข "$newTitle" แล้ว'),
                                backgroundColor: Colors.green[700],
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemImage(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 40),
      );
    }
    if (imageUrl.isNotEmpty) {
      try {
        final file = File(imageUrl);
        return Image.file(
          file,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.image, size: 40),
        );
      } catch (_) {
        return const Icon(Icons.image, size: 40);
      }
    }
    return const Icon(Icons.shopping_bag, size: 40, color: Colors.purple);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Marketplace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชหน้าจอ',
            onPressed: _refresh,
          ),
          IconButton(
            icon: Badge(
              label: Text('${context.watch<CartModel>().itemCount}'),
              child: const Icon(Icons.shopping_cart),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CheckoutPage()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Item>>(
          future: _itemsFuture,
          builder: (context, snapshot) {
            final apiItems = snapshot.data ?? [];

            // รวมสินค้าของผู้ใช้จากทั้ง State และไฟล์บันทึกถาวร (ตัดรายการซ้ำ)
            final seenIds = <int>{};
            final allUserItems = <Item>[];
            for (final it in [...widget.userItems, ...UserItemsStorage.items]) {
              if (seenIds.add(it.id)) {
                allUserItems.add(it);
              }
            }

            // รวมสินค้าของผู้ใช้ไว้บนสุดร่วมกับสินค้า API
            final allItems = [...allUserItems, ...apiItems];

            if (snapshot.connectionState == ConnectionState.waiting && allItems.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError && allItems.isEmpty) {
              return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
            }

            if (allItems.isEmpty) {
              return const Center(child: Text('ไม่พบสินค้า'));
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: allItems.length,
              itemBuilder: (context, index) {
                final item = allItems[index];
                final isUserItem = index < allUserItems.length;

                final isFavorited = _favoriteItemIds.contains(item.id);

                return ListTile(
                  onTap: () => _openEditItem(item),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildItemImage(item.imageUrl),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    isUserItem
                        ? '${item.price > 0 ? '${item.price.toStringAsFixed(0)} บาท' : 'ตามตกลง'} • หมวด: ${item.category}'
                        : '${item.price} บาท',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isFavorited ? Icons.favorite : Icons.favorite_border,
                          color: isFavorited ? Colors.red : null,
                        ),
                        tooltip: isFavorited ? 'ยกเลิกถูกใจ' : 'ถูกใจ',
                        onPressed: () async {
                          try {
                            if (isFavorited) {
                              await widget.favoritesRepository.removeFavorite(item.id);
                              setState(() {
                                _favoriteItemIds.remove(item.id);
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('นำ "${item.title}" ออกจากรายการโปรดแล้ว'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            } else {
                              await widget.favoritesRepository.addFavorite(
                                item.id,
                                item.title,
                                item.price,
                                item.imageUrl,
                              );
                              setState(() {
                                _favoriteItemIds.add(item.id);
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('เพิ่ม "${item.title}" ลงรายการโปรดแล้ว'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('เกิดข้อผิดพลาด: $e'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_shopping_cart),
                        tooltip: 'เพิ่มลงตะกร้า',
                        onPressed: () {
                          context.read<CartModel>().add(item);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('เพิ่ม "${item.title}" ลงตะกร้าแล้ว')),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('กำลังเรียก Gemini API...')),
          );

          try {
            final result = await GeminiService().generateText(
              'ช่วยแต่งประโยคทักทายลูกค้าร้านค้าออนไลน์แบบเป็นกันเอง',
            );

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
              );
            }
          }
        },
        child: const Icon(Icons.chat),
      ),
    );
  }
}
