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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ComicProvider>(context, listen: false).fetchComics();
    });
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

    Map<String, List<Comic>> groupedComics = {};
    for (var comic in provider.comics) {
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
          "PALM COMICS",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () => provider.fetchComics(),
          ),
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
          preferredSize: const Size.fromHeight(4),
          child: Container(color: Colors.black, height: 4),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                String category = categories[index];
                List<Comic> comics = groupedComics[category]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Transform.rotate(
                        angle: -0.02,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5252),
                            border: Border.all(color: Colors.black, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(3, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                    ...comics.map((comic) => Container(
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
                              width: 60,
                              height: 90,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                              child: comic.coverUrl.isNotEmpty
                                  ? Image.network(
                                      comic.coverUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.book, size: 40),
                                    )
                                  : const Icon(Icons.book, size: 40),
                            ),
                            title: Text(
                              comic.title.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            trailing: comic.isDownloaded
                                ? const Icon(Icons.check_box,
                                    color: Colors.green, size: 32)
                                : IconButton(
                                    icon: const Icon(Icons.download_for_offline,
                                        color: Colors.black, size: 32),
                                    onPressed: () => provider.downloadComic(comic),
                                  ),
                            onTap: () => _openComic(comic),
                          ),
                        )),
                  ],
                );
              },
            ),
    );
  }
}
