import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'comic_reader.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ComicProvider>(context);
    final downloadedComics = provider.comics.where((c) => c.isDownloaded).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFEB3B),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "DOWNLOADED COMICS",
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
          preferredSize: const Size.fromHeight(4),
          child: Container(color: Colors.black, height: 4),
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
                    "NO DOWNLOADS YET!",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("DOWNLOAD COMICS"),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: downloadedComics.length,
              itemBuilder: (context, index) {
                final comic = downloadedComics[index];
                return Container(
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
                      "READY FOR OFFLINE READING",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    trailing: const Icon(Icons.play_circle_fill,
                        color: Colors.black, size: 32),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ComicReaderScreen(comic: comic),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
