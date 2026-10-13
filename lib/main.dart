import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:infinite_image_galleryapp/services/unsplash_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const InfiniteImageGalleryApp());
}

/// ---------------------------------------------------------------
/// Favorites store (persisted with shared_preferences)
/// ---------------------------------------------------------------
class FavoritesStore extends ChangeNotifier {
  static const _key = 'favorite_photos';
  final Map<String, Map<String, dynamic>> _items = {};

  List<Map<String, dynamic>> get items => _items.values.toList();

  bool isFavorite(String id) => _items.containsKey(id);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    _items.clear();
    for (final s in raw) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      _items[map['id'] as String] = map;
    }
    notifyListeners();
  }

  Future<void> toggle(Map<String, dynamic> photo) async {
    final id = photo['id'] as String;
    if (_items.containsKey(id)) {
      _items.remove(id);
    } else {
      // Store only what we need, keeps prefs small.
      _items[id] = {
        'id': id,
        'description': photo['description'],
        'alt_description': photo['alt_description'],
        'urls': photo['urls'],
        'user': {'name': photo['user']?['name']},
      };
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _items.values.map(jsonEncode).toList());
  }
}

final favoritesStore = FavoritesStore();

/// ---------------------------------------------------------------
/// App
/// ---------------------------------------------------------------
class InfiniteImageGalleryApp extends StatefulWidget {
  const InfiniteImageGalleryApp({super.key});

  @override
  State<InfiniteImageGalleryApp> createState() =>
      _InfiniteImageGalleryAppState();
}

class _InfiniteImageGalleryAppState extends State<InfiniteImageGalleryApp> {
  @override
  void initState() {
    super.initState();
    favoritesStore.load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Infinite Image Gallery',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const GalleryHomePage(),
    );
  }
}

/// ---------------------------------------------------------------
/// Helpers
/// ---------------------------------------------------------------
String photoDescription(Map<String, dynamic> photo) {
  final d = photo['description'] as String?;
  final a = photo['alt_description'] as String?;
  final text = (d != null && d.trim().isNotEmpty) ? d : a;
  if (text == null || text.trim().isEmpty) return 'No description available';
  return text[0].toUpperCase() + text.substring(1);
}

Widget photoTile(
  Map<String, dynamic> photo, {
  required VoidCallback onTap,
  String size = 'small',
}) {
  final imageUrl = photo['urls']?[size] as String?;
  final id = photo['id'] as String;

  return GestureDetector(
    onTap: onTap,
    child: Hero(
      tag: 'photo_$id',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imageUrl == null
            ? const ColoredBox(
                color: Colors.black12,
                child: Center(child: Icon(Icons.broken_image)),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                cacheWidth: 600, // decode smaller = less memory
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const ColoredBox(
                    color: Colors.black12,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const ColoredBox(
                    color: Colors.black12,
                    child: Center(child: Icon(Icons.broken_image)),
                  );
                },
              ),
      ),
    ),
  );
}

SliverGridDelegate responsiveGrid(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  final columns = width >= 1000
      ? 5
      : width >= 700
      ? 4
      : width >= 450
      ? 3
      : 2;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
    childAspectRatio: 0.75,
  );
}

/// ---------------------------------------------------------------
/// Gallery Home
/// ---------------------------------------------------------------
class GalleryHomePage extends StatefulWidget {
  const GalleryHomePage({super.key});

  @override
  State<GalleryHomePage> createState() => _GalleryHomePageState();
}

class _GalleryHomePageState extends State<GalleryHomePage> {
  final List<Map<String, dynamic>> _photos = [];
  final ScrollController _controller = ScrollController();

  int _page = 1;
  bool _isLoading = true; // first load
  bool _isLoadingMore = false;
  bool _hasMore = true;

  String? _error; // first-load error
  String? _loadMoreError; // pagination error (shown at bottom of grid)

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _loadPhotos();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;

    final maxScroll = _controller.position.maxScrollExtent;
    final currentScroll = _controller.position.pixels;

    // Bottom-ku 200 pixels munnadi varum bodhe trigger aagum
    if (currentScroll >= (maxScroll - 200)) {
      if (!_isLoadingMore &&
          !_isLoading &&
          _hasMore &&
          _loadMoreError == null) {
        _loadMorePhotos();
      }
    }
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _loadMoreError = null;
    });

    try {
      final photos = await UnsplashService.fetchPhotos(page: 1);
      if (!mounted) return;

      setState(() {
        _photos
          ..clear()
          ..addAll(photos);
        _page = 1;
        _hasMore = photos.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMorePhotos() async {
    if (_isLoading || _isLoadingMore || !_hasMore || _loadMoreError != null) {
      return;
    }

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _page + 1;
      final photos = await UnsplashService.fetchPhotos(page: nextPage);

      if (!mounted) return;

      if (photos.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }

      final existingIds = _photos.map((p) => p['id']).toSet();
      final newPhotos = photos
          .where((p) => !existingIds.contains(p['id']))
          .toList();

      setState(() {
        _photos.addAll(newPhotos);
        _page = nextPage;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      print('PAGINATION ERROR: $e'); // Console-la error ennanu paakka
      setState(() {
        _isLoadingMore = false;
        _loadMoreError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _retryLoadMore() {
    setState(() => _loadMoreError = null);
    _loadMorePhotos();
  }

  void _openDetail(Map<String, dynamic> photo) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PhotoDetailPage(photo: photo)));
  }

  Widget _footer() {
    if (_loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_loadMoreError!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _retryLoadMore,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('You reached the end')),
      );
    }
    return const SizedBox(height: 16);
  }

  Widget _body() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _photos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadPhotos,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPhotos,
      child: CustomScrollView(
        controller: _controller,
        // Always scrollable, so pull-to-refresh and pagination work
        // even when the first page is short.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: SliverGrid(
              gridDelegate: responsiveGrid(context),
              delegate: SliverChildBuilderDelegate((context, index) {
                final photo = _photos[index];
                return photoTile(photo, onTap: () => _openDetail(photo));
              }, childCount: _photos.length),
            ),
          ),
          SliverToBoxAdapter(child: _footer()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Infinite Image Gallery',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Favorites',
            icon: const Icon(Icons.favorite),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const FavoritesPage()));
            },
          ),
        ],
      ),
      body: _body(),
    );
  }
}

/// ---------------------------------------------------------------
/// Detail
/// ---------------------------------------------------------------
class PhotoDetailPage extends StatefulWidget {
  const PhotoDetailPage({super.key, required this.photo});

  final Map<String, dynamic> photo;

  @override
  State<PhotoDetailPage> createState() => _PhotoDetailPageState();
}

class _PhotoDetailPageState extends State<PhotoDetailPage> {
  bool _downloading = false;

  Future<void> _download() async {
    final url =
        (widget.photo['urls']?['full'] ?? widget.photo['urls']?['regular'])
            as String?;
    if (url == null) return;

    setState(() => _downloading = true);

    try {
      // Gal asks for the needed permission itself.
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          _snack('Storage permission denied');
          return;
        }
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Download failed (${response.statusCode})');
      }

      await Gal.putImageBytes(
        response.bodyBytes,
        album: 'InfiniteGallery',
        name: 'photo_${widget.photo['id']}.jpg',
      );

      _snack('Saved to gallery');
    } catch (e) {
      _snack(
        'Download failed: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final id = photo['id'] as String;
    final imageUrl = photo['urls']?['regular'] as String?;
    final author = photo['user']?['name'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo'),
        actions: [
          ListenableBuilder(
            listenable: favoritesStore,
            builder: (context, _) {
              final isFav = favoritesStore.isFavorite(id);
              return IconButton(
                tooltip: isFav ? 'Remove favorite' : 'Add favorite',
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.red : null,
                ),
                onPressed: () => favoritesStore.toggle(photo),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          Hero(
            tag: 'photo_$id',
            child: imageUrl == null
                ? const SizedBox(
                    height: 300,
                    child: Center(child: Icon(Icons.broken_image, size: 48)),
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 300,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                          height: 300,
                          child: Center(
                            child: Icon(Icons.broken_image, size: 48),
                          ),
                        ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photoDescription(photo),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (author != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Photo by $author on Unsplash',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _downloading ? null : _download,
                    icon: _downloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: Text(_downloading ? 'Downloading...' : 'Download'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------
/// Favorites
/// ---------------------------------------------------------------
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: ListenableBuilder(
        listenable: favoritesStore,
        builder: (context, _) {
          final items = favoritesStore.items;

          if (items.isEmpty) {
            return const Center(child: Text('No favorites yet'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: responsiveGrid(context),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final photo = items[index];
              return photoTile(
                photo,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PhotoDetailPage(photo: photo),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
