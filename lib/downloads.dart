import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'comic_reader.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

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
    
    final downloadingAndDownloaded = provider.comics.where((c) {
      final isDownloading = provider.downloadingIds.containsKey(c.id);
      final matchesSearch = c.title.toLowerCase().contains(_searchQuery.toLowerCase());
      return (c.isDownloaded || isDownloading) && matchesSearch;
    }).toList();

    Map<String, List<Comic>> groupedComics = {};
    for (var comic in downloadingAndDownloaded) {
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
        title: const Text(
          "DOWNLOADS",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
      body: downloadingAndDownloaded.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 80, color: Colors.black26),
                  const SizedBox(height: 16),
                  const Text(
                    "NO DOWNLOADS FOUND",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
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
                      child: Transform.rotate(
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
                    ),
                    SizedBox(
                      height: 280,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        scrollDirection: Axis.horizontal,
                        itemCount: comics.length,
                        itemBuilder: (context, cIndex) {
                          return DownloadComicCard(
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
    );
  }
}

class DownloadComicCard extends StatelessWidget {
  final Comic comic;
  final VoidCallback onTap;

  const DownloadComicCard({super.key, required this.comic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<ComicProvider>(
      builder: (context, provider, child) {
        final currentComic = provider.comics.firstWhere(
          (c) => c.id == comic.id,
          orElse: () => comic,
        );
        final isDownloading = provider.downloadingIds.containsKey(currentComic.id);
        final progress = provider.downloadingIds[currentComic.id] ?? 0.0;

        return Container(
          width: 150,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Dismissible(
            key: Key('download_card_${currentComic.id}'),
            direction: DismissDirection.up,
            onDismissed: (direction) {
              provider.deleteDownloadedComic(currentComic);
            },
            background: Container(
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete, color: Colors.white, size: 32),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: currentComic.isDownloaded ? onTap : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                        ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          currentComic.coverUrl.isNotEmpty
                              ? Image.network(
                                  currentComic.coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(child: Icon(Icons.book, size: 40)),
                                )
                              : const Center(child: Icon(Icons.book, size: 40)),
                          if (isDownloading)
                            Container(
                              color: Colors.black.withOpacity(0.7),
                              child: Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: CircularProgressIndicator(
                                        value: progress > 0 ? progress : null,
                                        strokeWidth: 6,
                                        color: const Color(0xFFFFEB3B),
                                        backgroundColor: Colors.white24,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.stop,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
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
                          currentComic.title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        currentComic.isDownloaded
                            ? Icons.play_circle_fill
                            : Icons.downloading,
                        size: 20,
                        color: currentComic.isDownloaded ? Colors.black : Colors.grey,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
