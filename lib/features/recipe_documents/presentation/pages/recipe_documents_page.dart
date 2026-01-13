import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/repositories/recipe_document_repository.dart';
import '../../../../data/repositories/recipe_document_category_repository.dart';
import '../../../../data/models/recipe_document.dart';
import '../../../../data/models/recipe_document_category.dart';
import 'add_recipe_document_page.dart';
import 'recipe_document_detail_page.dart';
import 'manage_categories_page.dart';
import '../widgets/document_card.dart';
import '../widgets/category_chip.dart';

class RecipeDocumentsPage extends StatefulWidget {
  const RecipeDocumentsPage({super.key});

  @override
  State<RecipeDocumentsPage> createState() => _RecipeDocumentsPageState();
}

class _RecipeDocumentsPageState extends State<RecipeDocumentsPage> {
  final _repo = RecipeDocumentRepository();
  final _categoryRepo = RecipeDocumentCategoryRepository();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  // Virtual scroll / pagination state
  List<RecipeDocument> _allDocuments = [];
  List<RecipeDocument> _filteredDocuments = [];
  List<RecipeDocumentCategory> _categories = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 20; // Load 20 items at a time

  String _searchQuery = '';
  String? _selectedCategoryId;
  bool _showFavouritesOnly = false;
  String? _contentTypeFilter; // 'file' or 'text' or null for all

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when user scrolls near bottom (80% of scroll)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_loadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 0;
      _hasMore = true;
      _allDocuments.clear();
      _filteredDocuments.clear();
    }

    setState(() => _loading = true);
    try {
      // Load categories (only once)
      if (_categories.isEmpty) {
        final categories = await _categoryRepo.getAll();
        setState(() {
          _categories = categories;
        });
      }

      // Load first page of documents
      final documents = await _repo.getAll(
        categoryId: _selectedCategoryId,
        isFavourite: _showFavouritesOnly ? true : null,
        contentType: _contentTypeFilter,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        limit: _pageSize,
        offset: 0,
      );

      setState(() {
        _allDocuments = documents;
        _hasMore = documents.length == _pageSize; // If we got full page, might have more
        _applyFilters();
        _loading = false;
        _currentPage = 0;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading documents: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;

    setState(() => _loadingMore = true);
    try {
      final nextPage = _currentPage + 1;
      final documents = await _repo.getAll(
        categoryId: _selectedCategoryId,
        isFavourite: _showFavouritesOnly ? true : null,
        contentType: _contentTypeFilter,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        limit: _pageSize,
        offset: nextPage * _pageSize,
      );

      setState(() {
        _allDocuments.addAll(documents);
        _hasMore = documents.length == _pageSize; // If we got full page, might have more
        _currentPage = nextPage;
        _applyFilters();
        _loadingMore = false;
      });
    } catch (e) {
      setState(() => _loadingMore = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading more documents: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    final newQuery = _searchController.text;
    if (newQuery != _searchQuery) {
      setState(() {
        _searchQuery = newQuery;
      });
      // Reload data when search changes (server-side search)
      _loadData(refresh: true);
    }
  }

  void _applyFilters() {
    // For virtual scroll, we apply server-side filters, so filtered = all
    // Client-side filtering only for text_content search (if needed)
    var filtered = List<RecipeDocument>.from(_allDocuments);

    // Only client-side filter for text_content (if search is active)
    // Note: Title search is already done server-side
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((doc) {
        // Title already filtered server-side, only check text_content here
        return doc.title.toLowerCase().contains(query) ||
            (doc.textContent?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    setState(() {
      _filteredDocuments = filtered;
    });
  }

  void _onFilterChanged() {
    // Reload data when filters change
    _loadData(refresh: true);
  }

  Future<void> _refresh() async {
    await _loadData(refresh: true);
  }

  Future<void> _toggleFavourite(RecipeDocument document) async {
    try {
      await _repo.toggleFavourite(document.id);
      // Update local state immediately for better UX
      setState(() {
        final index = _allDocuments.indexWhere((d) => d.id == document.id);
        if (index != -1) {
          _allDocuments[index] = RecipeDocument(
            id: _allDocuments[index].id,
            businessOwnerId: _allDocuments[index].businessOwnerId,
            title: _allDocuments[index].title,
            description: _allDocuments[index].description,
            categoryId: _allDocuments[index].categoryId,
            contentType: _allDocuments[index].contentType,
            fileName: _allDocuments[index].fileName,
            filePath: _allDocuments[index].filePath,
            fileType: _allDocuments[index].fileType,
            fileSize: _allDocuments[index].fileSize,
            textContent: _allDocuments[index].textContent,
            tags: _allDocuments[index].tags,
            isFavourite: !_allDocuments[index].isFavourite,
            linkedRecipeId: _allDocuments[index].linkedRecipeId,
            uploadedAt: _allDocuments[index].uploadedAt,
            lastViewedAt: _allDocuments[index].lastViewedAt,
            viewCount: _allDocuments[index].viewCount,
            source: _allDocuments[index].source,
            createdAt: _allDocuments[index].createdAt,
            updatedAt: DateTime.now(),
          );
          _applyFilters();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating favourite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(RecipeDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam Dokumen'),
        content: Text('Adakah anda pasti mahu memadam "${document.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Padam'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repo.delete(document.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dokumen telah dipadam'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting document: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final favourites = _allDocuments.where((d) => d.isFavourite).take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('📚 Dokumen Resepi Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: 'Urus Kategori',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageCategoriesPage()),
              );
              _loadData(refresh: true);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '🔍 Cari dokumen...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddRecipeDocumentPage(),
                          ),
                        );
                        if (result == true) {
                          _loadData(refresh: true);
                        }
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Baru'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Category filter chips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📁 Kategori:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        CategoryChip(
                          label: 'Semua',
                          isSelected: _selectedCategoryId == null,
                          onTap: () {
                            setState(() {
                              _selectedCategoryId = null;
                            });
                            _onFilterChanged();
                          },
                        ),
                        ..._categories.map((category) => CategoryChip(
                              label: '${category.displayIcon} ${category.name}',
                              isSelected: _selectedCategoryId == category.id,
                              onTap: () {
                                setState(() {
                                  _selectedCategoryId = category.id;
                                });
                                _onFilterChanged();
                              },
                            )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Content type filter
                    Row(
                      children: [
                        FilterChip(
                          label: const Text('📄 File'),
                          selected: _contentTypeFilter == 'file',
                          onSelected: (selected) {
                            setState(() {
                              _contentTypeFilter = selected ? 'file' : null;
                            });
                            _onFilterChanged();
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('📝 Text'),
                          selected: _contentTypeFilter == 'text',
                          onSelected: (selected) {
                            setState(() {
                              _contentTypeFilter = selected ? 'text' : null;
                            });
                            _onFilterChanged();
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('⭐ Favorit'),
                          selected: _showFavouritesOnly,
                          onSelected: (selected) {
                            setState(() {
                              _showFavouritesOnly = selected;
                            });
                            _onFilterChanged();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Favourites section
            if (favourites.isNotEmpty && !_showFavouritesOnly && _selectedCategoryId == null && _searchQuery.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⭐ Favorit (${favourites.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(), // Smooth scrolling on mobile
                          padding: const EdgeInsets.symmetric(horizontal: 4.0), // Add padding for edge scrolling
                          itemCount: favourites.length,
                          itemBuilder: (context, index) {
                            final doc = favourites[index];
                            return SizedBox(
                              width: 200,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0), // Consistent padding
                                child: DocumentCard(
                                  document: doc,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RecipeDocumentDetailPage(documentId: doc.id),
                                      ),
                                    );
                                    _loadData(refresh: true);
                                  },
                                  onFavourite: () => _toggleFavourite(doc),
                                  onDelete: () => _deleteDocument(doc),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

            // All documents list
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '📋 Semua Dokumen (${_filteredDocuments.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredDocuments.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty || _selectedCategoryId != null || _showFavouritesOnly
                            ? 'Tiada dokumen dijumpai'
                            : 'Tiada dokumen lagi',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (_searchQuery.isEmpty && _selectedCategoryId == null && !_showFavouritesOnly)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddRecipeDocumentPage(),
                                ),
                              );
                              if (result == true) {
                                _loadData();
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Tambah Dokumen Pertama'),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final doc = _filteredDocuments[index];
                    return DocumentCard(
                      document: doc,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeDocumentDetailPage(documentId: doc.id),
                          ),
                        );
                        _loadData();
                      },
                      onFavourite: () => _toggleFavourite(doc),
                      onDelete: () => _deleteDocument(doc),
                    );
                  },
                  childCount: _filteredDocuments.length,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
