import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart'; // ไฟล์นี้ build_runner จะสร้างให้อัตโนมัติ

@DriftDatabase(tables: [FavoriteItems, ListingDrafts]) // ต้องระบุทุกตารางให้ครบ
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1; // เพิ่มเลขนี้ทุกครั้งที่แก้ Schema พร้อมเขียน Migration

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory(); // โฟลเดอร์ที่แอปเขียนไฟล์ได้
      final file = File(p.join(dbFolder.path, 'campus_marketplace.sqlite')); // ชื่อไฟล์ฐานข้อมูลจริง
      return NativeDatabase.createInBackground(file); // เปิดใน Thread แยกจาก UI ไม่ให้แอปกระตุก
    });
  }
}

