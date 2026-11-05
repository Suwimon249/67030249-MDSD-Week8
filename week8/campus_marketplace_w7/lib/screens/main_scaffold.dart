import 'dart:io';
import 'package:flutter/material.dart';
import 'favorites_page.dart';
import 'home_page.dart';
import 'sell_item_page.dart';
import '../models/item.dart';
import '../models/listing_draft.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/favorites_repository_drift.dart';
import '../repositories/item_repository.dart';
import '../repositories/listing_draft_repository.dart';
import '../services/user_items_storage.dart';

class MainScaffold extends StatefulWidget {
  final ItemRepository itemRepository;
  final FavoritesRepository favoritesRepository;
  final ListingDraftRepository draftRepository;

  const MainScaffold({
    super.key,
    required this.itemRepository,
    required this.favoritesRepository,
    required this.draftRepository,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  final List<Item> _userItems = [];

  @override
  void initState() {
    super.initState();
    // โหลดสินค้าที่เคยบันทึกไว้ในเครื่อง
    UserItemsStorage.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _onListingConfirmed(ListingDraft draft, File? imageFile, double price) async {
    final newItem = Item(
      id: DateTime.now().millisecondsSinceEpoch,
      title: draft.title,
      price: price,
      description: draft.description,
      category: draft.category,
      imageUrl: imageFile?.path ?? '',
    );

    // บันทึกลง Storage ทันที เพื่อป้องกันข้อมูลหายเวลารีเฟรช
    await UserItemsStorage.add(newItem);

    setState(() {
      _userItems.removeWhere((i) => i.id == newItem.id);
      _userItems.insert(0, newItem);
      // สลับหน้าจอไปยังแท็บหน้าหลักทันที เพื่อให้เห็นสินค้าที่เพิ่งลงขาย
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        repository: widget.itemRepository,
        favoritesRepository: widget.favoritesRepository,
        userItems: _userItems,
      ),
      SellItemPage(
        onListingConfirmed: _onListingConfirmed,
        draftRepository: widget.draftRepository,
      ),
      FavoritesPage(repository: widget.favoritesRepository),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 2 || index == 0) {
            FavoritesRepositoryDrift.updateNotifier.value++;
          }
          setState(() => _selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'หน้าหลัก'),
          BottomNavigationBarItem(icon: Icon(Icons.add_a_photo), label: 'ลงประกาศขาย'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'รายการโปรด'),
        ],
      ),
    );
  }
}
