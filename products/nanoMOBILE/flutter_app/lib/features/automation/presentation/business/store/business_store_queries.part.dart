part of 'business_store_content.dart';

/// Consultas locales sobre los productos existentes; no alteran precio ni inventario.
extension _StoreQueries on _BusinessStoreContentState {
  List<String> get _categories {
    final set = <String>{};
    for (final p in widget.products) {
      if (p.category != null && p.category!.trim().isNotEmpty) set.add(p.category!.trim());
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  Map<String, int> get _categoryCounts {
    final map = <String, int>{};
    for (final p in widget.products) {
      final cat = (p.category != null && p.category!.trim().isNotEmpty)
          ? p.category!.trim()
          : 'Sin categoría';
      map[cat] = (map[cat] ?? 0) + 1;
    }
    return map;
  }

  List<BusinessProduct> get _filteredProducts {
    final q = _query.toLowerCase().trim();
    var list = widget.products.where((p) {
      final mQ =
          q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.details.toLowerCase().contains(q) ||
          (p.sku != null && p.sku!.toLowerCase().contains(q)) ||
          (p.category != null && p.category!.toLowerCase().contains(q));
      final mC =
          _selectedCategory.isEmpty ||
          (p.category != null && p.category!.trim().toLowerCase() == _selectedCategory.toLowerCase());
      return mQ && mC;
    }).toList();

    switch (_sortBy) {
      case 'price_asc':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'stock':
        list.sort((a, b) => (b.stock ?? 0).compareTo(a.stock ?? 0));
        break;
      case 'name':
      default:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }
    return list;
  }
}
