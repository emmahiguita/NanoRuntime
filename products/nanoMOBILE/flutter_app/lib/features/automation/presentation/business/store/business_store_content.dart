// business_store_content.dart
//
// QUÉ HACE:
// Contenedor principal de la pestaña Tienda / Catálogo en la Biblioteca comercial.
// Integra filtros reactivos, búsqueda, ordenamiento y renderizado en Grid o Lista.
//
// CÓMO FUNCIONA:
// - Filtra en memoria los productos de `BusinessFacts` por texto y categoría sin duplicar datos.
// - Ordena deterministamente por nombre, precio o stock según la preferencia del usuario.
//
// POR QUÉ:
// Aplica SOLID (Single Responsibility) manteniendo la vista de Tienda en < 150 líneas.

import 'package:flutter/material.dart';
import '../../../engine/business/business_product.dart';
import 'business_store_category_filters.dart';
import 'business_store_empty_state.dart';
import 'business_store_product_card.dart';
import 'business_store_product_detail_sheet.dart';
import 'business_store_product_list_row.dart';
import 'business_store_toolbar.dart';

class BusinessStoreContent extends StatefulWidget {
  final List<BusinessProduct> products;
  final VoidCallback onAddProduct;
  final ValueChanged<BusinessProduct> onEditProduct;
  final ValueChanged<BusinessProduct> onShareProduct;

  const BusinessStoreContent({
    super.key,
    required this.products,
    required this.onAddProduct,
    required this.onEditProduct,
    required this.onShareProduct,
  });

  @override
  State<BusinessStoreContent> createState() => _BusinessStoreContentState();
}

class _BusinessStoreContentState extends State<BusinessStoreContent> {
  String _query = '';
  String _selectedCategory = '';
  String _sortBy = 'name';
  bool _isGridView = true;

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
      final cat = (p.category != null && p.category!.trim().isNotEmpty) ? p.category!.trim() : 'Sin categoría';
      map[cat] = (map[cat] ?? 0) + 1;
    }
    return map;
  }

  List<BusinessProduct> get _filteredProducts {
    final q = _query.toLowerCase().trim();
    var list = widget.products.where((p) {
      final mQ = q.isEmpty || p.name.toLowerCase().contains(q) || p.details.toLowerCase().contains(q) ||
          (p.sku != null && p.sku!.toLowerCase().contains(q)) || (p.category != null && p.category!.toLowerCase().contains(q));
      final mC = _selectedCategory.isEmpty || (p.category != null && p.category!.trim().toLowerCase() == _selectedCategory.toLowerCase());
      return mQ && mC;
    }).toList();

    switch (_sortBy) {
      case 'price_asc': list.sort((a, b) => a.price.compareTo(b.price)); break;
      case 'price_desc': list.sort((a, b) => b.price.compareTo(a.price)); break;
      case 'stock': list.sort((a, b) => (b.stock ?? 0).compareTo(a.stock ?? 0)); break;
      case 'name': default: list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())); break;
    }
    return list;
  }

  void _showDetail(BusinessProduct p) => BusinessStoreProductDetailSheet.show(
        context,
        product: p,
        onEdit: widget.onEditProduct,
        onShare: widget.onShareProduct,
      );

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;
    final isFiltering = _query.isNotEmpty || _selectedCategory.isNotEmpty;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: BusinessStoreToolbar(
            query: _query,
            sortBy: _sortBy,
            isGridView: _isGridView,
            onQueryChanged: (q) => setState(() => _query = q),
            onSortChanged: (s) => setState(() => _sortBy = s),
            onToggleView: () => setState(() => _isGridView = !_isGridView),
            onAddProduct: widget.onAddProduct,
          ),
        ),
        if (_categories.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: BusinessStoreCategoryFilters(
                categories: _categories,
                categoryCounts: _categoryCounts,
                selectedCategory: _selectedCategory,
                totalCount: widget.products.length,
                onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
              ),
            ),
          ),
        if (products.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: BusinessStoreEmptyState(
              isSearchOrFilter: isFiltering,
              onAction: isFiltering ? () => setState(() { _query = ''; _selectedCategory = ''; }) : widget.onAddProduct,
            ),
          )
        else if (_isGridView)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.69,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => BusinessStoreProductCard(product: products[i], onTap: _showDetail, onEdit: widget.onEditProduct, onShare: widget.onShareProduct),
                childCount: products.length,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => BusinessStoreProductListRow(product: products[i], onTap: _showDetail, onEdit: widget.onEditProduct, onShare: widget.onShareProduct),
                childCount: products.length,
              ),
            ),
          ),
      ],
    );
  }
}
