import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

class ComicReaderScreen extends StatefulWidget {
  final Comic comic;

  const ComicReaderScreen({super.key, required this.comic});

  @override
  State<ComicReaderScreen> createState() => _ComicReaderScreenState();
}

class _ComicReaderScreenState extends State<ComicReaderScreen> {
  List<Uint8List> _pages = [];
  bool _loading = true;
  int _currentPage = 0;
  int _savedPage = 0;
  bool _showContinuePrompt = false;
  bool _uiVisible = true;
  String _status = "Initializing...";
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadComic();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadComic() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedPage = prefs.getInt('last_page_${widget.comic.id}') ?? 0;

      String filePath;
      if (widget.comic.isDownloaded) {
        setState(() => _status = "Reading local file...");
        final directory = await getApplicationDocumentsDirectory();
        final fileName = p.basename(Uri.parse(widget.comic.downloadUrl).path);
        filePath = p.join(directory.path, fileName);
      } else {
        setState(() => _status = "Downloading...");
        final directory = await getTemporaryDirectory();
        filePath = p.join(directory.path, "temp_comic.cbz");
        await Dio().download(widget.comic.downloadUrl, filePath);
      }

      setState(() => _status = "Decoding pages...");
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      
      final images = await compute(_decodeArchive, bytes);

      if (mounted) {
        setState(() {
          _pages = images;
          _loading = false;
          if (_savedPage > 0 && _savedPage < _pages.length) {
            _showContinuePrompt = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  static List<Uint8List> _decodeArchive(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    List<Uint8List> pages = [];

    final imageFiles = archive.files.where((f) {
      if (!f.isFile) return false;
      final name = f.name.toLowerCase();
      return name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.webp');
    }).toList();

    imageFiles.sort((a, b) => a.name.compareTo(b.name));

    for (var file in imageFiles) {
      final content = file.content;
      if (content is Uint8List) {
        pages.add(content);
      } else {
        pages.add(Uint8List.fromList(List<int>.from(content)));
      }
    }
    return pages;
  }

  Future<void> _saveCurrentPage(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_page_${widget.comic.id}', index);
  }

  void _jumpToPage(int index) {
    if (index >= 0 && index < _pages.length) {
      _pageController.jumpToPage(index);
      setState(() {
        _currentPage = index;
        _showContinuePrompt = false;
      });
    }
  }

  void _showJumpDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFEB3B),
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Colors.black, width: 3),
        ),
        title: const Text("GO TO PAGE", style: TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: "1 - ${_pages.length}",
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null) _jumpToPage(page - 1);
              Navigator.pop(context);
            },
            child: const Text("GO", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _uiVisible
          ? AppBar(
              backgroundColor: const Color(0xFFFFEB3B),
              elevation: 0,
              title: Text(
                widget.comic.title.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, fontSize: 14),
              ),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFFFEB3B)),
                  const SizedBox(height: 20),
                  Text(_status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : Stack(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _uiVisible = !_uiVisible),
                  child: PhotoViewGallery.builder(
                    itemCount: _pages.length,
                    pageController: _pageController,
                    builder: (context, index) {
                      return PhotoViewGalleryPageOptions(
                        imageProvider: MemoryImage(_pages[index]),
                        initialScale: PhotoViewComputedScale.contained,
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 2,
                      );
                    },
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                      _saveCurrentPage(index);
                    },
                    scrollPhysics: const BouncingScrollPhysics(),
                    backgroundDecoration: const BoxDecoration(color: Colors.black),
                  ),
                ),
                if (_uiVisible && _showContinuePrompt)
                  Positioned(
                    top: 10,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "CONTINUE FROM PAGE ${_savedPage + 1}?",
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _jumpToPage(_savedPage),
                            child: const Text(
                            "CONTINUE",
                              style: TextStyle(
                                color: Color(0xFFFF5252),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => setState(() => _showContinuePrompt = false),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_uiVisible)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: GestureDetector(
                      onTap: _showJumpDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEB3B),
                          border: Border.all(color: Colors.black, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
                        ),
                        child: Text(
                          "${_currentPage + 1} / ${_pages.length}",
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
