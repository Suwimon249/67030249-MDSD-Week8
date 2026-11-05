import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/listing_draft.dart';
import 'listing_draft_repository.dart';

// Implementation: จัดการร่างประกาศขายสินค้าด้วย Drift SQLite
class ListingDraftRepositoryDrift implements ListingDraftRepository {
  final AppDatabase _db;
  ListingDraftRepositoryDrift(this._db); // รับ AppDatabase ทาง Constructor (DI)

  // บันทึกร่างประกาศใหม่ โดยนำฟิลด์จาก ListingDraft มารวมกับ imagePath
  @override
  Future<void> saveDraft(ListingDraft draft, String imagePath) {
    return _db.into(_db.listingDrafts).insert(
      ListingDraftsCompanion.insert(
        title: draft.title,
        category: draft.category,
        description: draft.description,
        imagePath: imagePath,
      ),
    );
  }

  // อ่านร่างประกาศทั้งหมด เรียงจากที่แก้ไขล่าสุดไปเก่าสุด
  @override
  Future<List<ListingDraftRow>> getAllDrafts() {
    return (_db.select(_db.listingDrafts)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  // ลบร่างประกาศตาม id
  @override
  Future<void> deleteDraft(int id) {
    return (_db.delete(_db.listingDrafts)
          ..where((t) => t.id.equals(id)))
        .go();
  }
}
