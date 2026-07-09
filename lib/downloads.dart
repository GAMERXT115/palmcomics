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
    final downloadedComics = provider.comics.where((c) {
      final matchesSearch = c.title.toLowerCase().contains(_searchQuery.toLowerCase());
      return c.isDownloaded && matchesSearch;
    }).toList();

    Map<String, List<Comic>> groupedComics = {};
    for (var comic in downloadedComics) {
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
      body: downloadedComics.isEmpty
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
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: comics.length,
                      itemBuilder: (context, cIndex) {
                        final comic = comics[cIndex];
                        return Dismissible(
                          key: Key('download_${comic.id}'),
                          direction: DismissDirection.endToStart,
                          onDismissed: (direction) {
                            provider.deleteDownloadedComic(comic);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("${comic.title} DELETED"),
                                backgroundColor: Colors.black,
                              ),
                            );
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.only(bottom: 16),
                            color: Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white, size: 32),
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.black, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(4, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(8),
                              leading: Container(
                                width: 50,
                                height: 75,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black, width: 2),
                                ),
                                child: comic.coverUrl.isNotEmpty
                                    ? Image.network(
                                        comic.coverUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.book, size: 30),
                                      )
                                    : const Icon(Icons.book, size: 30),
                              ),
                              title: Text(
                                comic.title.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: const Text(
                                "READY FOR OFFLINE",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                              trailing: const Icon(Icons.play_circle_fill,
                                  color: Colors.black, size: 32),
                              onTap: () => _openComic(comic),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
    );
  }
}
