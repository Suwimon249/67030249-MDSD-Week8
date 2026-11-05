import '../database/app_database.dart';
import '../models/listing_draft.dart';

// Interface: กำหนดความสามารถสำหรับจัดการร่างประกาศขายสินค้า
abstract class ListingDraftRepository {
  Future<void> saveDraft(ListingDraft draft, String imagePath);
  Future<List<ListingDraftRow>> getAllDrafts();
  Future<void> deleteDraft(int id);
}
