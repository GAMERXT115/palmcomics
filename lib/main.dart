import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isIOS) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyC8WrbLRWrggHUapK3Rt8unvM3BHY6xP6s',
        appId: '1:73084774791:ios:b73a5e725360c06d6dcb22',
        messagingSenderId: '73084774791',
        projectId: 'palmcomics-50edb',
        databaseURL: 'https://palmcomics-50edb-default-rtdb.europe-west1.firebasedatabase.app',
        storageBucket: 'palmcomics-50edb.firebasestorage.app',
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

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
  bool _isRequestingPermission = false;
  final Dio _dio = Dio();
  String _baseUrl = "";
  final Map<String, double> _downloadingIds = {};
  final Map<String, CancelToken> _cancelTokens = {};

  List<Comic> get comics => _comics;
  bool get isLoading => _isLoading;
  String get baseUrl => _baseUrl;
  Map<String, double> get downloadingIds => _downloadingIds;

  void updateBaseUrl(String newUrl) {
    _baseUrl = newUrl;
    notifyListeners();
  }

  Future<void> fetchServerIp() async {
    try {
      final database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://palmcomics-50edb-default-rtdb.europe-west1.firebasedatabase.app',
      );
      final ref = database.ref('serverInfo');
      final snapshot = await ref.get();
      
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final publicIp = data['ip'];
        final privateIp = data['privateIp'];
        final port = data['port2'] ?? 9091;

        try {
          final testDio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 3)));
          await testDio.get("http://$privateIp:$port/comics");
          _baseUrl = "http://$privateIp:$port";
        } catch (e) {
          _baseUrl = "http://$publicIp:$port";
        }
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> fetchComics() async {
    if (_baseUrl.isEmpty) {
      await fetchServerIp();
    }
    
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
      debugPrint(e.toString());
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
    notifyListeners();
  }

  Future<void> downloadComic(Comic comic) async {
    if (_downloadingIds.containsKey(comic.id)) return;

    if (Platform.isAndroid) {
      if (_isRequestingPermission) return;
      _isRequestingPermission = true;
      try {
        var status = await Permission.storage.request();
        _isRequestingPermission = false;
        if (!status.isGranted) return;
      } catch (e) {
        _isRequestingPermission = false;
        return;
      }
    }

    final cancelToken = CancelToken();
    _cancelTokens[comic.id] = cancelToken;
    _downloadingIds[comic.id] = 0.0;
    notifyListeners();

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = p.basename(Uri.parse(comic.downloadUrl).path);
      final filePath = p.join(directory.path, fileName);

      await _dio.download(
        comic.downloadUrl,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _downloadingIds[comic.id] = received / total;
            notifyListeners();
          }
        },
      );

      comic.isDownloaded = true;
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      _downloadingIds.remove(comic.id);
      _cancelTokens.remove(comic.id);
      notifyListeners();
    }
  }

  void cancelDownload(String id) {
    if (_cancelTokens.containsKey(id)) {
      _cancelTokens[id]!.cancel();
      _cancelTokens.remove(id);
      _downloadingIds.remove(id);
      notifyListeners();
    }
  }

  Future<void> deleteDownloadedComic(Comic comic) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = p.basename(Uri.parse(comic.downloadUrl).path);
      final filePath = p.join(directory.path, fileName);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
      }

      comic.isDownloaded = false;
      notifyListeners();
    } catch (e) {
      debugPrint(e.toString());
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
