import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'downloads.dart';
import 'comic_reader.dart';

class ComicListScreen extends StatefulWidget {
  const ComicListScreen({super.key});

  @override
  State<ComicListScreen> createState() => _ComicListScreenState();
}

class _ComicListScreenState extends State<ComicListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ComicProvider>(context, listen: false).fetchComics();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openComic(Comic comic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComicReaderScreen(comic: comic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ComicProvider>(context);

    final filteredComics = provider.comics.where((c) {
      return c.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    Map<String, List<Comic>> groupedComics = {};
    for (var comic in filteredComics) {
      String category = comic.category.toUpperCase();
      if (!groupedComics.containsKey(category)) {
        groupedComics[category] = [];
      }
      groupedComics[category]!.add(comic);
    }

    List<String> categories = groupedComics.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFEB3B),
        elevation: 0,
        centerTitle: true,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        title: const Text(
          "PALM COMICS",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_done_rounded, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DownloadsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 3),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: const InputDecoration(
                    hintText: "SEARCH...",
                    hintStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    prefixIcon: Icon(Icons.search, color: Colors.black),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              Container(color: Colors.black, height: 4),
            ],
          ),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
              color: Colors.black,
              backgroundColor: const Color(0xFFFFEB3B),
              onRefresh: () => provider.fetchComics(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  String category = categories[index];
                  List<Comic> comics = groupedComics[category]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Transform.rotate(
                              angle: -0.15,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5252),
                                  border: Border.all(color: Colors.black, width: 3),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                                  ],
                                ),
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CategoryGridView(
                                      category: category,
                                      comics: comics,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  border: Border.all(color: Colors.black, width: 2),
                                ),
                                child: const Text(
                                  "VIEW ALL",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 280,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          scrollDirection: Axis.horizontal,
                          itemCount: comics.length > 20 ? 20 : comics.length,
                          itemBuilder: (context, cIndex) {
                            return ComicPosterCard(
                              comic: comics[cIndex],
                              onTap: () => _openComic(comics[cIndex]),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class ComicPosterCard extends StatelessWidget {
  final Comic comic;
  final VoidCallback onTap;

  const ComicPosterCard({super.key, required this.comic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ComicProvider>(context, listen: false);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                  ],
                ),
                child: comic.coverUrl.isNotEmpty
                    ? Image.network(
                        comic.coverUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(child: Icon(Icons.book, size: 40)),
                      )
                    : const Center(child: Icon(Icons.book, size: 40)),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      comic.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (!comic.isDownloaded)
                    GestureDetector(
                      onTap: () => provider.downloadComic(comic),
                      child: const Icon(
                        Icons.download_for_offline,
                        color: Colors.black,
                        size: 24,
                      ),
                    )
                  else
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 24,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryGridView extends StatefulWidget {
  final String category;
  final List<Comic> comics;

  const CategoryGridView({super.key, required this.category, required this.comics});

  @override
  State<CategoryGridView> createState() => _CategoryGridViewState();
}

class _CategoryGridViewState extends State<CategoryGridView> {
  final TextEditingController _categorySearchController = TextEditingController();
  String _categoryQuery = "";

  @override
  void dispose() {
    _categorySearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategoryComics = widget.comics.where((c) {
      return c.title.toLowerCase().contains(_categoryQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFEB3B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.category,
          style: const TextStyle(fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 3),
                ),
                child: TextField(
                  controller: _categorySearchController,
                  onChanged: (value) => setState(() => _categoryQuery = value),
                  decoration: InputDecoration(
                    hintText: "SEARCH IN ${widget.category}...",
                    hintStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: Colors.black),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              Container(color: Colors.black, height: 4),
            ],
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.6,
          crossAxisSpacing: 16,
          mainAxisSpacing: 20,
        ),
        itemCount: filteredCategoryComics.length,
        itemBuilder: (context, index) {
          return ComicPosterCard(
            comic: filteredCategoryComics[index],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ComicReaderScreen(comic: filteredCategoryComics[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
