import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'home.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ComicProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class Comic {
  final String id;
  final String title;
  final String category;
  final String coverUrl;
  final String downloadUrl;
  bool isDownloaded;

  Comic({
    required this.id,
    required this.title,
    required this.category,
    required this.coverUrl,
    required this.downloadUrl,
    this.isDownloaded = false,
  });

  factory Comic.fromJson(Map<String, dynamic> json) {
    return Comic(
      id: json['id'].toString(),
      title: json['title'] ?? 'Unknown',
      category: json['category'] ?? 'UNCATEGORIZED',
      coverUrl: json['coverUrl'] ?? '',
      downloadUrl: json['downloadUrl'] ?? '',
    );
  }
}

class ComicProvider extends ChangeNotifier {
  List<Comic> _comics = [];
  bool _isLoading = false;
  final Dio _dio = Dio();
  String _baseUrl = "";

  List<Comic> get comics => _comics;
  bool get isLoading => _isLoading;

  void updateBaseUrl(String newUrl) {
    _baseUrl = newUrl;
    notifyListeners();
  }

  Future<void> fetchComics() async {
    if (_baseUrl.isEmpty) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _dio.get("$_baseUrl/comics");
      if (response.statusCode == 200) {
        List data = response.data;
        _comics = data.map((item) => Comic.fromJson(item)).toList();
        await _checkDownloadedStatus();
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _checkDownloadedStatus() async {
    final directory = await getApplicationDocumentsDirectory();
    for (var comic in _comics) {
      final fileName = p.basename(Uri.parse(comic.downloadUrl).path);
      final filePath = p.join(directory.path, fileName);
      comic.isDownloaded = await File(filePath).exists();
    }
  }

  Future<void> downloadComic(Comic comic) async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      if (!status.isGranted) return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = p.basename(Uri.parse(comic.downloadUrl).path);
      final filePath = p.join(directory.path, fileName);

      await _dio.download(
        comic.downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            debugPrint("${(received / total * 100).toStringAsFixed(0)}%");
          }
        },
      );

      comic.isDownloaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Download Error: $e");
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Palm Comics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFEB3B)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const ComicListScreen(),
      },
    );
  }
}
