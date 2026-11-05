import '../database/app_database.dart';

// Interface: ระบุว่า Widget "ทำอะไรได้บ้าง" โดยไม่ระบุว่า "ทำอย่างไร"
abstract class FavoritesRepository {
  Future<void> addFavorite(int itemId, String title, double price, String imageUrl);
  Future<List<FavoriteItem>> getAllFavorites();
  Future<void> removeFavorite(int itemId);
}

