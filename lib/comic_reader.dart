import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:page_flip/page_flip.dart';
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
  double _downloadProgress = 0;
  Timer? _pageSyncTimer;
  final GlobalKey<PageFlipWidgetState> _controller = GlobalKey<PageFlipWidgetState>();

  @override
  void initState() {
    super.initState();
    _loadComic();
    _startPageSync();
  }

  @override
  void dispose() {
    _pageSyncTimer?.cancel();
    super.dispose();
  }

  void _startPageSync() {
    _pageSyncTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_controller.currentState != null) {
        int index = _controller.currentState!.pageNumber;
        if (index != _currentPage) {
          setState(() {
            _currentPage = index;
          });
          _saveCurrentPage(index);
        }
      }
    });
  }

  Future<void> _loadComic() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedPage = prefs.getInt('last_page_${widget.comic.id}') ?? 0;

      String filePath = "";
      final docDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      
      final fileName = p.basename(Uri.parse(widget.comic.downloadUrl).path);
      final permanentPath = p.join(docDir.path, fileName);
      final tempPath = p.join(tempDir.path, "temp_${widget.comic.id}.cbz");

      if (await File(permanentPath).exists()) {
        setState(() => _status = "Reading local file...");
        filePath = permanentPath;
      } else if (await File(tempPath).exists()) {
        setState(() => _status = "Reading from cache...");
        filePath = tempPath;
      } else {
        setState(() => _status = "Downloading...");
        final provider = Provider.of<ComicProvider>(context, listen: false);
        
        String downloadUrl = widget.comic.downloadUrl;
        if (!downloadUrl.startsWith(provider.baseUrl) && provider.baseUrl.isNotEmpty) {
          final uri = Uri.parse(downloadUrl);
          downloadUrl = "${provider.baseUrl}${uri.path}";
        }

        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 5),
        ));

        await dio.download(
          downloadUrl,
          tempPath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              setState(() {
                _downloadProgress = received / total;
              });
            }
          },
        );
        filePath = tempPath;
      }

      setState(() => _status = "Decoding pages...");
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      
      final images = await compute(_decodeArchive, bytes);

      if (images.isEmpty) throw Exception("No images found in comic file");

      if (mounted) {
        for (var imageBytes in images) {
          precacheImage(MemoryImage(imageBytes), context);
        }

        setState(() {
          _pages = images;
          if (_savedPage >= _pages.length) {
            _savedPage = 0;
          }
          _currentPage = _savedPage;
          _loading = false;
          if (_savedPage > 0) {
            _showContinuePrompt = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: "RETRY",
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  _loading = true;
                  _downloadProgress = 0;
                });
                _loadComic();
              },
            ),
          ),
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
      return name.endsWith('.jpg') || 
             name.endsWith('.jpeg') || 
             name.endsWith('.png') || 
             name.endsWith('.webp');
    }).toList();

    imageFiles.sort((a, b) => a.name.compareTo(b.name));

    for (var file in imageFiles) {
      final content = file.content as List<int>;
      pages.add(Uint8List.fromList(content));
    }
    
    archive.clear();
    return pages;
  }

  Future<void> _saveCurrentPage(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_page_${widget.comic.id}', index);
  }

  void _jumpToPage(int index) {
    if (index >= 0 && index < _pages.length) {
      _controller.currentState?.goToPage(index);
      setState(() {
        _currentPage = index;
        _showContinuePrompt = false;
      });
      _saveCurrentPage(index);
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
    return Consumer<ComicProvider>(
      builder: (context, provider, child) {
        final currentComic = provider.comics.firstWhere(
          (c) => c.id == widget.comic.id,
          orElse: () => widget.comic,
        );
        final isDownloading = provider.downloadingIds.containsKey(currentComic.id);
        final progress = provider.downloadingIds[currentComic.id] ?? 0.0;

        return Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              if (_loading)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              value: _downloadProgress > 0 ? _downloadProgress : null,
                              color: const Color(0xFFFFEB3B),
                              strokeWidth: 8,
                            ),
                          ),
                          if (_downloadProgress > 0 && _downloadProgress < 1.0)
                            Text(
                              "${(_downloadProgress * 100).toInt()}%",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _status, 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)
                      ),
                    ],
                  ),
                )
              else
                PageFlipWidget(
                  key: _controller,
                  backgroundColor: Colors.black,
                  initialIndex: _savedPage < _pages.length ? _savedPage : 0,
                  lastPage: RepaintBoundary(
                    child: GestureDetector(
                      onTap: () => setState(() => _uiVisible = !_uiVisible),
                      child: Container(color: Colors.black),
                    ),
                  ),
                  isRightSwipe: false,
                  children: <Widget>[
                    ..._pages.asMap().entries.map((entry) {
                      return RepaintBoundary(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _uiVisible = !_uiVisible),
                          child: Container(
                            key: ValueKey('page_container_${entry.key}'),
                            color: Colors.black,
                            child: InteractiveViewer(
                              minScale: 1.0,
                              maxScale: 4.0,
                              panEnabled: true,
                              scaleEnabled: true,
                              child: Center(
                                child: Image.memory(
                                  entry.value,
                                  key: ValueKey('page_image_${entry.key}'),
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                  filterQuality: FilterQuality.medium,
                                  isAntiAlias: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                top: (_uiVisible || isDownloading || _loading) ? 0 : -(kToolbarHeight + MediaQuery.of(context).padding.top + 20),
                left: 0,
                right: 0,
                child: Container(
                  height: kToolbarHeight + MediaQuery.of(context).padding.top,
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEB3B),
                    border: Border(bottom: BorderSide(color: Colors.black, width: 3)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.comic.title.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _buildHeaderDownloadAction(provider, currentComic, isDownloading, progress),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_loading && _uiVisible && _showContinuePrompt)
                Positioned(
                  top: kToolbarHeight + MediaQuery.of(context).padding.top + 20,
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
              if (!_loading)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  bottom: _uiVisible ? 20 : -100,
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
                        "PAGE ${_currentPage + 1} OF ${_pages.length}",
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderDownloadAction(ComicProvider provider, Comic currentComic, bool isDownloading, double progress) {
    if (currentComic.isDownloaded) {
      return const Icon(
        Icons.check_circle,
        color: Colors.black,
        size: 28,
      );
    }

    if (isDownloading) {
      return GestureDetector(
        onTap: () => provider.cancelDownload(currentComic.id),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 4,
                color: Colors.black,
                backgroundColor: Colors.black12,
              ),
            ),
            const Icon(
              Icons.stop,
              size: 14,
              color: Colors.black,
            ),
          ],
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.download_for_offline, color: Colors.black, size: 28),
      onPressed: () => provider.downloadComic(currentComic),
    );
  }
}
