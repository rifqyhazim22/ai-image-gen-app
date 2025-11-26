// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Configure via --dart-define to keep secrets out of code.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);
Gradient appBackground(Brightness brightness) {
  if (brightness == Brightness.dark) {
    return const LinearGradient(
      colors: [Color(0xFF0B1224), Color(0xFF121C3A), Color(0xFF0E2F47)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  return const LinearGradient(
    colors: [Color(0xFFF2F1FF), Color(0xFFE7F4FF), Color(0xFFFDF1FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception(
      'Set SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define before running.',
    );
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  String _lang = 'en';
  Session? _session;
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _initAuth();
    _startSplash();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('themeMode');
    final lang = prefs.getString('lang');
    setState(() {
      if (theme == 'dark') _themeMode = ThemeMode.dark;
      if (theme == 'light') _themeMode = ThemeMode.light;
      if (lang == 'id') _lang = 'id';
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', _themeMode == ThemeMode.dark ? 'dark' : 'light');
    await prefs.setString('lang', _lang);
  }

  void _initAuth() {
    final supabase = Supabase.instance.client;
    _session = supabase.auth.currentSession;
    supabase.auth.onAuthStateChange.listen((event) {
      setState(() {
        _session = event.session;
      });
    });
  }

  Future<void> _startSplash() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() {
        _splashDone = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Splash
    if (!_splashDone) {
      return MaterialApp(
        title: 'AI Image Gen App',
        themeMode: _themeMode,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: appBackground(
                _themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Color(0x334276F5),
                    child: Icon(Icons.auto_awesome, size: 28),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'AI Image Gen',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Auth gate
    if (_session == null) {
      return MaterialApp(
        title: 'AI Image Gen App',
        themeMode: _themeMode,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: AuthScreen(
          lang: _lang,
          themeMode: _themeMode,
          onThemeChanged: (mode) {
            setState(() => _themeMode = mode);
            _savePrefs();
          },
          onLangChanged: (v) {
            setState(() => _lang = v);
            _savePrefs();
          },
          onDone: (session) {
            setState(() => _session = session);
          },
        ),
      );
    }

    // Main app
    return MaterialApp(
      title: 'AI Image Gen App',
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: HomePage(
        session: _session!,
        onLogout: () async {
          await Supabase.instance.client.auth.signOut();
          setState(() => _session = null);
        },
        lang: _lang,
        themeMode: _themeMode,
        onLangChanged: (v) {
          setState(() {
            _lang = v;
          });
          _savePrefs();
        },
        onThemeChanged: (mode) {
          setState(() {
            _themeMode = mode;
          });
          _savePrefs();
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final seed = isDark ? const Color(0xFF6DD4FF) : const Color(0xFF7B5CFF);
    final base = isDark ? const Color(0xFF0B1224) : const Color(0xFFF7F7FB);
    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
      scaffoldBackgroundColor: base,
      useMaterial3: true,
      textTheme: Typography.englishLike2021.apply(
        fontFamily: 'Montserrat',
        bodyColor: isDark ? Colors.white : const Color(0xFF1F2933),
        displayColor: isDark ? Colors.white : const Color(0xFF1F2933),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor:
            isDark ? Colors.black.withOpacity(0.15) : Colors.white.withOpacity(0.7),
        foregroundColor: isDark ? Colors.white : const Color(0xFF1F2933),
      ),
      cardColor: Colors.white.withOpacity(isDark ? 0.08 : 0.8),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.onThemeChanged,
    required this.onLangChanged,
    required this.themeMode,
    required this.lang,
  });

  final Session session;
  final VoidCallback onLogout;
  final void Function(ThemeMode) onThemeChanged;
  final void Function(String) onLangChanged;
  final ThemeMode themeMode;
  final String lang;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _picker = ImagePicker();
  final _uuid = const Uuid();
  final _promptController = TextEditingController(text: '');
  final List<String> _presets = const [
    'A cinematic portrait at sunset beach',
    'A neon-lit cyberpunk city portrait',
    'A soft studio headshot with rim light',
    'A moody black and white film portrait',
  ];
  String _aspect = '1:1'; // aspect ratio selection
  String _quality = 'low'; // low | medium | high
  String _mode = 'text'; // text | edit
  XFile? _picked;
  bool _loading = false;
  bool _uploadingOriginal = false;
  String? _error;
  final List<_GeneratedImage> _gallery = [];
  Uint8List? _previewBytes;
  String? _groupId;
  final Set<String> _groupHistory = {};
  bool _keepHistory = true;
  static const _maxBytes = 5 * 1024 * 1024; // 5MB cap
  bool _deleting = false;
  bool _loadingHistory = false;
  List<_GroupSummary> _history = [];
  static const int _historyInitialLimit = 100;
  static const int _historyStep = 100;
  int _historyLimit = _historyInitialLimit;
  String _lang = 'en';
  final List<String> _promptHistory = [];
  int _tabIndex = 0; // 0 chat, 1 history, 2 library
  final List<_GeneratedImage> _library = [];
  bool _libraryLoading = false;
  int _libraryOffset = 0;
  static const int _libraryPageSize = 30;
  static const String _legacyCombinedGroup = 'legacy-combined';

  @override
  void initState() {
    super.initState();
    _lang = widget.lang;
    _loadHistory();
    _gallery.clear();
    _groupId = null;
  }

  Map<String, Map<String, String>> get l10n => {
        'en': {
          'title': 'AI Image Gen',
          'lang_toggle': 'Switch language',
          'theme_toggle': 'Toggle theme',
          'upload_title': 'Upload portrait',
          'choose_photo': 'Choose Photo',
          'upload_hint': 'JPG/PNG up to 5MB. Stored privately.',
          'prompt_label': 'Prompt',
          'prompt_hint': 'Describe the image you want',
          'keep_history': 'Keep previous results when generating',
          'mode_label': 'Mode',
          'mode_text': 'Text → Image',
          'mode_edit': 'Text + Image (Edit)',
          'generate': 'Generate scenes',
          'clear_current': 'Clear current',
          'clear_all': 'Clear all',
          'results_title': 'Results',
          'generating': 'Generating your images...',
          'results_empty': 'Results will appear here after generation.',
          'history_title': 'History',
          'history_empty': 'No history yet.',
          'copy_link_success': 'Link copied to clipboard',
          'tab_chat': 'Chat',
          'tab_history': 'History',
          'tab_library': 'Library',
          'latest_session': 'Latest session',
          'new_session': 'New session',
          'open': 'Open',
          'open_link': 'Open link',
          'copy': 'Copy',
          'delete': 'Delete',
          'refresh': 'Refresh',
          'load_more': 'Load more',
          'download': 'Download',
          'share': 'Share',
        },
        'id': {
          'title': 'AI Image Gen',
          'lang_toggle': 'Ganti bahasa',
          'theme_toggle': 'Ganti tema',
          'upload_title': 'Unggah foto',
          'choose_photo': 'Pilih Foto',
          'upload_hint': 'JPG/PNG max 5MB. Disimpan privat.',
          'prompt_label': 'Prompt',
          'prompt_hint': 'Deskripsikan gambar yang diinginkan',
          'keep_history': 'Simpan hasil sebelumnya saat generate',
          'mode_label': 'Mode',
          'mode_text': 'Teks → Gambar',
          'mode_edit': 'Teks + Gambar (Edit)',
          'generate': 'Generate',
          'clear_current': 'Hapus batch ini',
          'clear_all': 'Hapus semua',
          'results_title': 'Hasil',
          'generating': 'Sedang membuat gambar...',
          'results_empty': 'Hasil akan muncul setelah generate.',
          'history_title': 'Riwayat',
          'history_empty': 'Belum ada riwayat.',
          'copy_link_success': 'Link tersalin',
          'tab_chat': 'Chat',
          'tab_history': 'Riwayat',
          'tab_library': 'Galeri',
          'latest_session': 'Sesi terbaru',
          'new_session': 'Sesi baru',
          'open': 'Buka',
          'open_link': 'Buka link',
          'copy': 'Salin',
          'delete': 'Hapus',
          'refresh': 'Muat ulang',
          'load_more': 'Muat lagi',
          'download': 'Unduh',
          'share': 'Bagikan',
        },
      };

  String t(String key) => l10n[_lang]?[key] ?? l10n['en']![key]!;

  Future<void> _loadHistory({bool loadMore = false}) async {
    setState(() {
      _loadingHistory = true;
    });
    try {
      final supabase = Supabase.instance.client;
      final userId = widget.session.user.id;
      final limit = loadMore ? _historyLimit + _historyStep : _historyInitialLimit;
      _historyLimit = limit;
      final res = await supabase
          .from('ai_images')
          .select('id,storage_path,scene,prompt,kind,group_id,created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      final data = (res as List<dynamic>? ?? [])
          .map((e) => _GeneratedImage.fromJson(e as Map<String, dynamic>))
          .toList();
      if (data.isNotEmpty) {
        final latest = data
            .where((e) => e.createdAt != null)
            .fold<DateTime?>(null, (prev, e) {
          if (e.createdAt == null) return prev;
          if (prev == null) return e.createdAt;
          return e.createdAt!.isAfter(prev) ? e.createdAt : prev;
        });
        setState(() {
          _history = [
            _GroupSummary(
              groupId: _legacyCombinedGroup,
              primaryText: 'All sessions',
              count: data.length,
              createdAt: latest ?? DateTime.now(),
            ),
          ];
          _groupHistory
            ..clear()
            ..add(_legacyCombinedGroup);
        });
      } else {
        setState(() {
          _history = [];
          _groupHistory.clear();
        });
      }
    } catch (e) {
      debugPrint('loadHistory error: $e');
    } finally {
      setState(() {
        _loadingHistory = false;
      });
    }
  }

  Future<void> _pickImage() async {
    if (_mode != 'edit') return;
    setState(() {
      _error = null;
    });
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 90,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxBytes) {
        setState(() {
          _error = 'File too large (>5MB). Please pick a smaller image.';
        });
        return;
      }
      final groupId = _groupId ?? _uuid.v4();
      setState(() {
        _picked = file;
        _previewBytes = bytes;
        _groupId = groupId;
      });
      await _uploadOriginal(bytes, groupId);
    }
  }

  Future<void> _uploadOriginal(Uint8List bytes, String groupId) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _error = 'User not signed in';
      });
      return;
    }
    setState(() {
      _uploadingOriginal = true;
      _error = null;
    });
    try {
      final path = '$userId/${_uuid.v4()}.jpg';
      await supabase.storage.from('ai-photo-remix').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      final data = await supabase
          .from('ai_images')
          .insert({
            'user_id': userId,
            'kind': 'original',
            'scene': 'original',
            'storage_path': path,
            'group_id': groupId,
          })
          .select('id, storage_path, scene, prompt, kind, group_id, created_at')
          .single();
      setState(() {
        _gallery.add(_GeneratedImage.fromJson(data).copyWith(bytes: bytes));
        _groupHistory.add(groupId);
      });
    } catch (e) {
      setState(() {
        _error = 'Upload original failed: $e';
      });
    } finally {
      setState(() {
        _uploadingOriginal = false;
      });
    }
  }

  Future<void> _generate() async {
    if (_mode == 'edit' && _picked == null) {
      setState(() {
        _error = 'Please choose an image for edit mode';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bytes = _picked != null ? await _picked!.readAsBytes() : null;
      final b64 = bytes != null ? base64Encode(bytes) : null;
      final groupId = _groupId ?? _uuid.v4();
      _groupId = groupId;
      final supabase = Supabase.instance.client;
      if (!_keepHistory && _groupId != null) {
        await _clearSession();
        _groupId = groupId;
      }
      final response = await supabase.functions.invoke(
        'generate_images',
        body: {
          'imageBase64': b64,
          'prompt': _promptController.text,
          'mode': _mode,
          'groupId': groupId,
          'aspect': _aspect,
          'quality': _quality,
        },
      );
      if (response.data == null) {
        throw Exception('Function returned null');
      }
      final data = response.data as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>? ?? [])
          .map((e) => _GeneratedImage.fromJson(e as Map<String, dynamic>))
          .toList();

      if (_promptController.text.isNotEmpty &&
          !_promptHistory.contains(_promptController.text)) {
        _promptHistory.insert(0, _promptController.text);
        if (_promptHistory.length > 10) _promptHistory.removeLast();
      }

      for (final item in list) {
        final res = await supabase.storage
            .from('ai-photo-remix')
            .download(item.storagePath);
        _gallery.add(item.copyWith(bytes: res));
        _groupHistory.add(groupId);
      }

      setState(() {});
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                child: const Icon(Icons.auto_awesome, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, ${widget.session.user.email ?? 'creator'}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    'Chat your visuals into life',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: '${t('lang_toggle')} 🌐',
            onPressed: () {
              setState(() {
                _lang = _lang == 'en' ? 'id' : 'en';
              });
              widget.onLangChanged(_lang);
            },
            icon: const Icon(Icons.language),
          ),
          IconButton(
            tooltip: '${t('theme_toggle')} ☀️/🌙',
            onPressed: () {
              final next =
                  widget.themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
              widget.onThemeChanged(next);
            },
            icon: Icon(
              widget.themeMode == ThemeMode.light ? Icons.nights_stay : Icons.wb_sunny,
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: appBackground(theme.brightness)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildChatTab(theme),
                _buildHistoryTab(theme),
                _buildLibraryTab(theme),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) {
          setState(() {
            _tabIndex = idx;
          });
          if (idx == 2) {
            _loadLibraryImages();
          }
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.chat_bubble_outline), label: t('tab_chat')),
          NavigationDestination(icon: const Icon(Icons.history), label: t('tab_history')),
          NavigationDestination(icon: const Icon(Icons.collections), label: t('tab_library')),
        ],
      ),
    );
  }

  Widget _buildChatTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                'Create & chat your images ✍️',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (kIsWeb) ...[
                    OutlinedButton.icon(
                      onPressed: () => launchUrlString(
                        'https://github.com/rifqyhazim22/ai-image-gen-app/releases',
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('Download app'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => launchUrlString(
                        'https://github.com/rifqyhazim22/ai-image-gen-app',
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.code),
                      label: const Text('GitHub'),
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _startNewSession,
                    icon: const Icon(Icons.fiber_new),
                    label: Text('${t('new_session')} ➕'),
                  ),
                ],
              ),
            ],
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 12),
            _buildDownloadPanel(theme),
          ],
          const SizedBox(height: 12),
          _buildChatFeed(theme),
          const SizedBox(height: 16),
          _buildChatComposer(theme),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildHistorySection(theme),
    );
  }

  Widget _buildLibraryTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('tab_library'), style: theme.textTheme.titleMedium),
              Row(
                children: [
                  IconButton(
                    tooltip: t('refresh'),
                    onPressed: _libraryLoading
                        ? null
                        : () {
                            setState(() {
                              _library.clear();
                              _libraryOffset = 0;
                            });
                            _loadLibraryImages();
                          },
                    icon: const Icon(Icons.refresh),
                  ),
                  if (_libraryLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildResultsGrid(
            customImages: _library,
            emptyText: t('results_empty'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: OutlinedButton.icon(
              onPressed: _libraryLoading ? null : _loadLibraryImages,
              icon: const Icon(Icons.expand_more),
              label: Text(t('load_more')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadPanel(ThemeData theme) {
    const releaseTag = 'v0.1.0';
    const baseUrl = 'https://github.com/rifqyhazim22/ai-image-gen-app/releases/download/$releaseTag';
    return Glass(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Download apps',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => launchUrlString(
                    '$baseUrl/ai-image-gen-app.apk',
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.android),
                  label: const Text('Android APK'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => launchUrlString(
                    '$baseUrl/ai-image-gen-app-macos.dmg',
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.apple),
                  label: const Text('macOS DMG'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => launchUrlString(
                    '$baseUrl/ai-image-gen-app-macos.zip',
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.laptop_mac),
                  label: const Text('macOS ZIP'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => launchUrlString(
                    'https://github.com/rifqyhazim22/ai-image-gen-app/releases',
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.download_for_offline),
                  label: const Text('All downloads'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'iOS: gunakan XCArchive di rilis untuk export/sign. Web bundle tersedia di rilis.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatFeed(ThemeData theme) {
    final images = _groupId == null
        ? _gallery
        : _gallery.where((img) => img.groupId == _groupId).toList();
    images.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });
    if (images.isEmpty) {
      return Glass(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Let\'s imagine something new',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Generate to see magic show up here.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...images.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildChatCard(item, theme),
            )),
      ],
    );
  }

  Widget _buildChatComposer(ThemeData theme) {
    return Glass(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _mode == 'edit' ? _buildUploadCard(theme) : _buildGlassHero(theme),
            const SizedBox(height: 12),
            _buildPromptAndMode(theme),
            const SizedBox(height: 12),
            _buildAction(theme),
            const SizedBox(height: 8),
            _buildClearButton(theme),
            if (_loading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              Center(child: Text(t('generating'))),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGlassHero(ThemeData theme) {
    return Glass(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              t('mode_text'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              t('prompt_hint'),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.2),
                    theme.colorScheme.secondary.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _mode == 'text' ? t('mode_text') : t('mode_edit'),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard(ThemeData theme) {
    return Glass(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              t('upload_title'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.12),
                    theme.colorScheme.secondary.withOpacity(0.12),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _previewBytes != null
                    ? Image.memory(
                        _previewBytes!,
                        width: 220,
                        height: 220,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 220,
                        height: 220,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.person, size: 72, color: Colors.grey),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : _pickImage,
              icon: const Icon(Icons.upload),
              label: Text(t('choose_photo')),
            ),
            const SizedBox(height: 8),
            Text(
              t('upload_hint'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptAndMode(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _promptController,
          decoration: InputDecoration(
            labelText: t('prompt_label'),
            hintText: t('prompt_hint'),
            border: const OutlineInputBorder(),
          ),
          minLines: 1,
          maxLines: 3,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presets
              .map(
                (p) => ChoiceChip(
                  label: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis),
                  selected: _promptController.text == p,
                  onSelected: (_) {
                    setState(() {
                      _promptController.text = p;
                    });
                  },
                ),
              )
              .toList(),
        ),
        if (_promptHistory.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _promptHistory
                .map(
                  (p) => ActionChip(
                    label: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onPressed: () {
                      setState(() {
                        _promptController.text = p;
                      });
                    },
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _mode,
          decoration: InputDecoration(
            labelText: t('mode_label'),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(value: 'text', child: Text(t('mode_text'))),
            DropdownMenuItem(value: 'edit', child: Text(t('mode_edit'))),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _mode = v;
              _groupId = null;
              _picked = null;
              _previewBytes = null;
            });
          },
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Switch(
              value: _keepHistory,
              onChanged: (val) {
                setState(() {
                  _keepHistory = val;
                });
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t('keep_history'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _buildAspectSelector(theme),
        const SizedBox(height: 8),
        _buildQualitySelector(theme),
        const SizedBox(height: 8),
        Text(
          _mode == 'text'
              ? 'Prompt only, no upload required.'
              : 'Upload required; prompt guides the edit.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildAction(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: (_mode == 'text'
                ? !_loading
                : (_picked != null && !_loading && !_uploadingOriginal))
            ? _generate
            : null,
        child: Text(t('generate')),
      ),
    );
  }

  Widget _buildClearButton(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _loading ? null : _clearSession,
          child: Text(t('clear_current')),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _loading ? null : _clearAllHistory,
          child: Text(t('clear_all')),
        ),
        const SizedBox(width: 8),
        Switch(
          value: _keepHistory,
          onChanged: _loading
              ? null
              : (val) {
                  setState(() {
                    _keepHistory = val;
                  });
                },
        ),
        const SizedBox(width: 4),
        const Text('Keep history'),
      ],
    );
  }

  Widget _buildAspectSelector(ThemeData theme) {
    final options = [
      {'label': '1:1', 'value': '1:1', 'icon': Icons.crop_square},
      {'label': '2:3', 'value': '2:3', 'icon': Icons.crop_portrait},
      {'label': '3:2', 'value': '3:2', 'icon': Icons.crop_landscape},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Aspect ratio', style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: options
              .map(
                (opt) => ChoiceChip(
                  avatar: Icon(opt['icon'] as IconData, size: 16),
                  label: Text(opt['label'] as String),
                  selected: _aspect == opt['value'],
                  onSelected: (_) {
                    setState(() {
                      _aspect = opt['value'] as String;
                    });
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildQualitySelector(ThemeData theme) {
    final options = [
      {'label': 'Low', 'value': 'low'},
      {'label': 'Medium', 'value': 'medium'},
      {'label': 'High', 'value': 'high'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quality', style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: options
              .map(
                (opt) => ChoiceChip(
                  label: Text(opt['label'] as String),
                  selected: _quality == opt['value'],
                  onSelected: (_) {
                    setState(() {
                      _quality = opt['value'] as String;
                    });
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Future<void> _clearSession() async {
    setState(() {
      _error = null;
    });
    final currentGroup = _groupId;
    if (_groupId != null) {
      try {
        final supabase = Supabase.instance.client;
        await supabase.functions.invoke('cleanup_group', body: {
          'groupId': _groupId,
        });
      } catch (e) {
        debugPrint('cleanup_group error: $e');
      }
    }
    setState(() {
      _picked = null;
      _previewBytes = null;
      if (currentGroup != null) {
        _gallery.removeWhere((item) => item.groupId == currentGroup);
        _groupHistory.remove(currentGroup);
        _history.removeWhere((h) => h.groupId == currentGroup);
      } else {
        _gallery.clear();
        _groupHistory.clear();
        _history.clear();
      }
      _groupId = null;
    });
  }

  Future<void> _clearAllHistory() async {
    setState(() {
      _error = null;
    });
    final supabase = Supabase.instance.client;
    for (final gid in _groupHistory) {
      try {
        await supabase.functions.invoke('cleanup_group', body: {'groupId': gid});
      } catch (e) {
        debugPrint('cleanup_group error for $gid: $e');
      }
    }
    setState(() {
      _gallery.clear();
      _groupHistory.clear();
      _history.clear();
      _groupId = null;
      _picked = null;
      _previewBytes = null;
    });
  }

  Widget _buildHistorySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(t('history_title'), style: theme.textTheme.titleMedium),
            if (_loadingHistory)
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_history.isEmpty && !_loadingHistory)
          Text(
            t('history_empty'),
            style: theme.textTheme.bodySmall,
          ),
        if (_history.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length,
            separatorBuilder: (context, separatorIndex) => const Divider(height: 8),
            itemBuilder: (context, idx) {
              final h = _history[idx];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text(
                  h.primaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${h.count} item(s) • ${h.createdAt}',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => _loadGroup(h.groupId),
                      child: const Text('View'),
                    ),
                    TextButton(
                      onPressed: _deleting ? null : () => _deleteGroup(h.groupId),
                      child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: OutlinedButton.icon(
            onPressed: _loadingHistory ? null : () => _loadHistory(loadMore: true),
            icon: const Icon(Icons.expand_more),
            label: Text(t('load_more')),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsGrid({String? filterGroup, String? emptyText, List<_GeneratedImage>? customImages}) {
    final base = customImages ?? _gallery;
    final images = filterGroup != null
        ? base.where((img) => img.groupId == filterGroup).toList()
        : base;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('results_title'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (images.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              emptyText ?? t('results_empty'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: images.length,
          itemBuilder: (context, idx) {
            final item = images[idx];
            return GestureDetector(
              onTap: () => _openModal(item),
              child: AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 350),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (item.bytes != null)
                        Image.memory(item.bytes!, fit: BoxFit.cover)
                      else
                        Container(color: Colors.grey.shade200),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.scene ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if ((item.kind ?? '').isNotEmpty)
                                Text(
                                  item.kind!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              if ((item.prompt ?? '').isNotEmpty)
                                Text(
                                  item.prompt!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildChatCard(_GeneratedImage item, ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Glass(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: item.bytes != null
                      ? Image.memory(
                          item.bytes!,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey.shade200,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.prompt ?? t('prompt_hint'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'AI',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.scene ?? '',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (item.createdAt != null)
                        Text(
                          '${item.createdAt}',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      if (item.createdAt != null)
                        Text(
                          '${item.createdAt}',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () => _openModal(item),
                            icon: const Icon(Icons.open_in_full, size: 18),
                            label: Text(t('open')),
                          ),
                          TextButton.icon(
                            onPressed: () => _copyLink(item),
                            icon: const Icon(Icons.link, size: 18),
                            label: Text(t('copy')),
                          ),
                          TextButton.icon(
                            onPressed: () => _openImageLink(item),
                            icon: const Icon(Icons.open_in_browser, size: 18),
                            label: Text(t('open_link')),
                          ),
                          TextButton.icon(
                            onPressed: () => _shareItem(item),
                            icon: const Icon(Icons.share, size: 18),
                            label: Text(t('share')),
                          ),
                          TextButton.icon(
                            onPressed: () => _downloadItem(item),
                            icon: const Icon(Icons.download, size: 18),
                            label: Text(t('download')),
                          ),
                          TextButton.icon(
                            onPressed: _deleting ? null : () => _deleteItem(item),
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            label: Text(
                              t('delete'),
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteItem(_GeneratedImage item) async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase.functions.invoke('delete_item', body: {
        'storagePath': item.storagePath,
      });
      if (res.data == null) throw Exception('Delete failed');
      setState(() {
        _gallery.removeWhere((i) => i.id == item.id);
        if (_gallery.where((i) => i.groupId == item.groupId).isEmpty &&
            item.groupId != null) {
          _groupHistory.remove(item.groupId);
          _history.removeWhere((h) => h.groupId == item.groupId);
          if (_groupId == item.groupId) _groupId = null;
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Delete failed: $e';
      });
    } finally {
      setState(() {
        _deleting = false;
      });
    }
  }

  Future<void> _copyLink(_GeneratedImage item) async {
    try {
      final url = await _getSignedUrl(item);
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('copy_link_success'))),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Copy link failed: $e';
      });
    }
  }

  Future<void> _downloadItem(_GeneratedImage item) async {
    try {
      final signed = await _getSignedUrl(item);
      await launchUrlString(signed, mode: LaunchMode.platformDefault);
    } catch (e) {
      setState(() {
        _error = 'Download failed: $e';
      });
    }
  }

  Future<void> _openImageLink(_GeneratedImage item) async {
    try {
      final signed = await _getSignedUrl(item);
      await launchUrlString(signed, mode: LaunchMode.platformDefault);
    } catch (e) {
      setState(() {
        _error = 'Open link failed: $e';
      });
    }
  }

  Future<void> _shareItem(_GeneratedImage item) async {
    try {
      final signed = await _getSignedUrl(item);
      await Clipboard.setData(ClipboardData(text: signed));
      await launchUrlString(signed, mode: LaunchMode.platformDefault);
    } catch (e) {
      setState(() {
        _error = 'Share failed: $e';
      });
    }
  }

  Future<String> _getSignedUrl(_GeneratedImage item) async {
    final supabase = Supabase.instance.client;
    final path = item.resolvedPath ?? item.storagePath;
    return supabase.storage
        .from('ai-photo-remix')
        .createSignedUrl(path, 3600);
  }

  Future<_GeneratedImage> _tryDownloadImage(_GeneratedImage item, String userId) async {
    final supabase = Supabase.instance.client;
    try {
      final res =
          await supabase.storage.from('ai-photo-remix').download(item.storagePath);
      return item.copyWith(bytes: res, resolvedPath: item.storagePath);
    } catch (e) {
      debugPrint('download error for ${item.storagePath}: $e');
    }

    final filename = item.storagePath.split('/').last;
    final altPath = '$userId/$filename';
    try {
      final res =
          await supabase.storage.from('ai-photo-remix').download(altPath);
      return item.copyWith(bytes: res, resolvedPath: altPath);
    } catch (e) {
      debugPrint('fallback download error for $altPath: $e');
      return item.copyWith(resolvedPath: item.storagePath);
    }
  }

  Future<void> _loadGroup(String groupId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      final userId = widget.session.user.id;
      final rows = groupId == _legacyCombinedGroup
          ? await supabase
              .from('ai_images')
              .select('id,storage_path,scene,prompt,kind,group_id,created_at')
              .eq('user_id', userId)
              .order('created_at', ascending: true)
              .limit(_historyLimit)
          : await supabase
              .from('ai_images')
              .select('id,storage_path,scene,prompt,kind,group_id,created_at')
              .eq('user_id', userId)
              .eq('group_id', groupId)
              .order('created_at', ascending: true);

      final items = (rows as List<dynamic>? ?? [])
          .map((e) => _GeneratedImage.fromJson(e as Map<String, dynamic>))
          .toList();
      final downloaded = <_GeneratedImage>[];
      for (final item in items) {
        final download = await _tryDownloadImage(item, userId);
        downloaded.add(download);
      }
      setState(() {
        _gallery
          ..clear()
          ..addAll(downloaded);
        _groupId = groupId == _legacyCombinedGroup ? null : groupId;
        if (_tabIndex != 0) _tabIndex = 0;
      });
    } catch (e) {
      setState(() {
        _error = 'Load group failed: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _deleteGroup(String groupId) async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      await supabase.functions.invoke('cleanup_group', body: {'groupId': groupId});
      setState(() {
        _gallery.removeWhere((i) => i.groupId == groupId);
        _library.removeWhere((i) => i.groupId == groupId);
        _groupHistory.remove(groupId);
        _history.removeWhere((h) => h.groupId == groupId);
        if (_groupId == groupId) _groupId = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Delete group failed: $e';
      });
    } finally {
      setState(() {
        _deleting = false;
      });
    }
  }

  void _openModal(_GeneratedImage item) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.transparent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dialogWidth = constraints.maxWidth.clamp(340.0, 580.0);
              final dialogHeight = constraints.maxHeight.clamp(340.0, 640.0);
              final imageMaxWidth = dialogWidth * 0.9;
              final imageMaxHeight = dialogHeight * 0.55;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: dialogWidth,
                    maxHeight: dialogHeight,
                  ),
                  child: Glass(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: 'Close',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          if (item.bytes != null)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: imageMaxWidth,
                                maxHeight: imageMaxHeight,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: InteractiveViewer(
                                  clipBehavior: Clip.hardEdge,
                                  minScale: 1,
                                  maxScale: 4,
                                  child: Image.memory(
                                    item.bytes!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            item.scene ?? '',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if ((item.prompt ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.prompt!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () => _openImageLink(item),
                                icon: const Icon(Icons.open_in_new),
                                label: Text(t('open_link')),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => _copyLink(item),
                                icon: const Icon(Icons.link),
                                label: Text(t('copy')),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => _shareItem(item),
                                icon: const Icon(Icons.share),
                                label: Text(t('share')),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => _downloadItem(item),
                                icon: const Icon(Icons.download),
                                label: Text(t('download')),
                              ),
                              OutlinedButton.icon(
                                onPressed: _deleting ? null : () => _deleteItem(item),
                                icon:
                                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                                label: Text(
                                  t('delete'),
                                  style: const TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _startNewSession() {
    setState(() {
      _groupId = null;
      _picked = null;
      _previewBytes = null;
      _gallery.clear();
      _error = null;
      _promptController.clear();
    });
  }


  Future<void> _loadLibraryImages() async {
    if (_libraryLoading) return;
    setState(() {
      _libraryLoading = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      final userId = widget.session.user.id;
      final rows = await supabase
          .from('ai_images')
          .select('id,storage_path,scene,prompt,kind,group_id,created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(_libraryOffset, _libraryOffset + _libraryPageSize - 1);
      final items = (rows as List<dynamic>? ?? [])
          .map((e) => _GeneratedImage.fromJson(e as Map<String, dynamic>))
          .toList();
      final downloaded = <_GeneratedImage>[];
      for (final item in items) {
        final download = await _tryDownloadImage(item, userId);
        downloaded.add(download);
      }
      setState(() {
        if (_libraryOffset == 0) _library.clear();
        _library.addAll(downloaded);
        _libraryOffset += _libraryPageSize;
      });
    } catch (e) {
      setState(() {
        _error = 'Load library failed: $e';
      });
    } finally {
      setState(() {
        _libraryLoading = false;
      });
    }
  }
}

class _GeneratedImage {
  final String id;
  final String storagePath;
  final String? scene;
  final Uint8List? bytes;
  final String? resolvedPath;
  final String? prompt;
  final String? kind;
  final String? groupId;
  final DateTime? createdAt;

  _GeneratedImage({
    required this.id,
    required this.storagePath,
    this.scene,
    this.bytes,
    this.resolvedPath,
    this.prompt,
    this.kind,
    this.groupId,
    this.createdAt,
  });

  factory _GeneratedImage.fromJson(Map<String, dynamic> json) {
    return _GeneratedImage(
      id: json['id'] as String,
      storagePath: json['storage_path'] as String,
      scene: json['scene'] as String?,
      prompt: json['prompt'] as String?,
      kind: json['kind'] as String?,
      groupId: json['group_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  _GeneratedImage copyWith({Uint8List? bytes, String? resolvedPath}) => _GeneratedImage(
        id: id,
        storagePath: storagePath,
        resolvedPath: resolvedPath ?? this.resolvedPath,
        scene: scene,
        bytes: bytes,
        prompt: prompt,
        kind: kind,
        groupId: groupId,
        createdAt: createdAt,
      );
}

class _GroupSummary {
  final String groupId;
  final String primaryText;
  final int count;
  final DateTime createdAt;

  _GroupSummary({
    required this.groupId,
    required this.primaryText,
    required this.count,
    required this.createdAt,
  });

  _GroupSummary copyWith({
    String? groupId,
    String? primaryText,
    int? count,
    DateTime? createdAt,
  }) {
    return _GroupSummary(
      groupId: groupId ?? this.groupId,
      primaryText: primaryText ?? this.primaryText,
      count: count ?? this.count,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class Glass extends StatelessWidget {
  const Glass({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.6);
    final accent = theme.colorScheme.primary.withOpacity(isDark ? 0.2 : 0.12);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [base, accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.lang,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onLangChanged,
    required this.onDone,
  });

  final String lang;
  final ThemeMode themeMode;
  final void Function(ThemeMode) onThemeChanged;
  final void Function(String) onLangChanged;
  final void Function(Session session) onDone;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Image Gen'),
        actions: [
          IconButton(
            tooltip: 'Lang 🌐',
            onPressed: () {
              widget.onLangChanged(widget.lang == 'en' ? 'id' : 'en');
            },
            icon: const Icon(Icons.language),
          ),
          IconButton(
            tooltip: 'Theme',
            onPressed: () {
              final next =
                  widget.themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
              widget.onThemeChanged(next);
            },
            icon: Icon(
              widget.themeMode == ThemeMode.light ? Icons.nights_stay : Icons.wb_sunny,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: appBackground(theme.brightness)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Glass(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isLogin ? 'Welcome back' : 'Create your account',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(_isLogin ? 'Login' : 'Sign up'),
                    ),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                              setState(() {
                                _isLogin = !_isLogin;
                                _error = null;
                              });
                            },
                      child: Text(_isLogin ? 'Need an account? Sign up' : 'Have an account? Login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final supabase = Supabase.instance.client;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    try {
      Session? session;
      if (_isLogin) {
        final res = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        session = res.session;
      } else {
        final res = await supabase.auth.signUp(
          email: email,
          password: password,
        );
        session = res.session;
        // Jika perlu konfirmasi email, session bisa null; coba login langsung.
        if (session == null && res.user != null) {
          try {
            final login = await supabase.auth.signInWithPassword(
              email: email,
              password: password,
            );
            session = login.session;
          } on AuthException catch (e) {
            setState(() {
              _error = e.message.isNotEmpty
                  ? e.message
                  : 'Please check your email to confirm, or retry in a minute.';
            });
          }
        }
      }

      if (session == null) {
        setState(() {
          _error = 'Auth failed, please try again. If this keeps happening, wait 1-2 minutes and retry.';
        });
        return;
      }
      widget.onDone(session);
    } on AuthException catch (e) {
      setState(() {
        _error = e.message.isNotEmpty ? e.message : 'Auth failed, please try again.';
      });
    } catch (e) {
      setState(() {
        _error = 'Auth error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

}
