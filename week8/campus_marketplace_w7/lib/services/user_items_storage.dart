import 'dart:convert';
import 'dart:io';
import '../models/item.dart';

class UserItemsStorage {
  // รายการสินค้าของผู้ใช้ที่บันทึกไว้ในหน่วยความจำ
  static final List<Item> items = [];

  // ไฟล์ JSON ที่เก็บข้อมูลถาวรในเครื่อง Emulator
  static File _getFile() {
    try {
      return File('/sdcard/Download/campus_marketplace_items.json');
    } catch (_) {
      return File('campus_marketplace_items.json');
    }
  }

  // โหลดรายการสินค้าเดิมที่เคยบันทึกไว้ขึ้นมา
  static Future<void> load() async {
    try {
      final file = _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> list = jsonDecode(content);
        items.clear();
        for (final json in list) {
          items.add(Item.fromJson(json as Map<String, dynamic>));
        }
      }
    } catch (_) {}
  }

  // บันทึกรายการทั้งหมดลงไฟล์
  static Future<void> _save() async {
    try {
      final file = _getFile();
      final list = items.map((e) => {
        'id': e.id,
        'title': e.title,
        'price': e.price,
        'description': e.description,
        'category': e.category,
        'image': e.imageUrl,
      }).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (_) {}
  }

  // เพิ่มสินค้าใหม่และบันทึกลงไฟล์ทันที ป้องกันข้อมูลหายเวลารีเฟรช
  static Future<void> add(Item item) async {
    items.removeWhere((i) => i.id == item.id);
    items.insert(0, item);
    await _save();
  }

  // อัปเดตข้อมูลสินค้าที่มีอยู่แล้ว
  static Future<void> update(Item item) async {
    final index = items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      items[index] = item;
    } else {
      items.insert(0, item);
    }
    await _save();
  }

  // ลบสินค้าออกจากระบบและบันทึกลงไฟล์
  static Future<void> remove(int id) async {
    items.removeWhere((i) => i.id == id);
    await _save();
  }
}

