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
// La vista conserva únicamente el estado de filtros y coordina los componentes del catálogo.

import 'package:flutter/material.dart';
import '../../../engine/business/business_product.dart';
import 'business_store_category_filters.dart';
import 'business_store_empty_state.dart';
import 'business_store_product_grid.dart';
import 'business_store_product_detail_sheet.dart';
import 'business_store_product_list_row.dart';
import 'business_store_toolbar.dart';

part 'business_store_queries.part.dart';

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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isFiltering ? 'Resultados' : 'Productos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${products.length}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        if (products.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: BusinessStoreEmptyState(
              isSearchOrFilter: isFiltering,
              onAction: isFiltering
                  ? () => setState(() {
                      _query = '';
                      _selectedCategory = '';
                    })
                  : widget.onAddProduct,
            ),
          )
        else if (_isGridView)
          BusinessStoreProductGrid(
            products: products,
            onTap: _showDetail,
            onEdit: widget.onEditProduct,
            onShare: widget.onShareProduct,
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => BusinessStoreProductListRow(
                  product: products[i],
                  onTap: _showDetail,
                  onEdit: widget.onEditProduct,
                  onShare: widget.onShareProduct,
                ),
                childCount: products.length,
              ),
            ),
          ),
      ],
    );
  }
}
