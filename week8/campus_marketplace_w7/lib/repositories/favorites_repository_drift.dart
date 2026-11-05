import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'favorites_repository.dart';

// Implementation: รู้รายละเอียดว่าใช้ Drift เก็บข้อมูลจริง
class FavoritesRepositoryDrift implements FavoritesRepository {
  final AppDatabase _db;
  FavoritesRepositoryDrift(this._db); // รับ AppDatabase ทาง Constructor (DI)

  // ตัวแจ้งเตือนเมื่อมีการเพิ่ม/ลบรายการโปรด เพื่อให้อัปเดตหน้าจอทันทีแบบ Real-time
  static final ValueNotifier<int> updateNotifier = ValueNotifier(0);

  // Create: เพิ่มสินค้าลงรายการถูกใจ
  @override
  Future<void> addFavorite(int itemId, String title, double price, String imageUrl) async {
    await _db.into(_db.favoriteItems).insert( // .into() ระบุตารางปลายทาง
      FavoriteItemsCompanion.insert( // Companion สร้างแถวใหม่โดยไม่ต้องระบุ id/addedAt
        itemId: itemId,
        title: title,
        price: price,
        imageUrl: imageUrl,
      ),
      mode: InsertMode.insertOrIgnore, // itemId ซ้ำ (ผิดกฎ .unique()) ให้ข้ามเงียบๆ แทนที่จะโยน Exception
    );
    updateNotifier.value++; // แจ้งเตือนหน้าจออื่นให้อัปเดตทันที
  }

  // Read: อ่านรายการถูกใจทั้งหมด เรียงจากล่าสุดไปเก่าสุด
  @override
  Future<List<FavoriteItem>> getAllFavorites() {
    return (_db.select(_db.favoriteItems) // เริ่ม Query จากตาราง favoriteItems
          ..orderBy([(t) => OrderingTerm.desc(t.addedAt)])) // เรียงล่าสุดก่อน
        .get(); // สั่งให้ Query ทำงานจริงและคืนผลลัพธ์
  }

  // Delete: เอาสินค้าออกจากรายการถูกใจด้วย itemId
  @override
  Future<void> removeFavorite(int itemId) async {
    await (_db.delete(_db.favoriteItems)
          ..where((t) => t.itemId.equals(itemId))) // ลบเฉพาะแถวที่ itemId ตรงกัน
        .go(); // .go() ใช้กับคำสั่งที่เปลี่ยนแปลงข้อมูล
    updateNotifier.value++; // แจ้งเตือนหน้าจออื่นให้อัปเดตทันที
  }
}

