import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:doc_text_extractor/doc_text_extractor.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const LegalReaderApp());

class LegalReaderApp extends StatelessWidget {
  const LegalReaderApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Legal Reader - قراءة سهلة',
      theme: ThemeData.dark().copyWith(
        textTheme: GoogleFonts.notoSansArabicTextTheme(),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _extractedText;
  String? _fileName;
  bool _isLoading = false;

  Future<void> _pickAndReadFile() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result != null) {
        final file = result.files.first;
        final bytes = await file.xFile.readAsBytes();

        final extractor = DocTextExtractor();
        final text = await extractor.extractText(bytes, fileName: file.name);

        setState(() {
          _extractedText = text;
          _fileName = file.name;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_file_name', file.name);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal Reader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickAndReadFile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _extractedText == null
              ? const Center(
                  child: Text(
                    'اضغط على الأيقونة أعلى يمين عشان تختار PDF أو Word',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : ReadingScreen(
                  text: _extractedText!,
                  fileName: _fileName!,
                ),
    );
  }
}

class ReadingScreen extends StatefulWidget {
  final String text;
  final String fileName;
  const ReadingScreen({super.key, required this.text, required this.fileName});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  double _fontSize = 18.0;
  bool _isDark = true;
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setupTTS();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _fontSize = prefs.getDouble('font_size') ?? 18.0);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', _fontSize);
  }

  Future<void> _setupTTS() async {
    await _flutterTts.setLanguage("ar-EG");
    await _flutterTts.setSpeechRate(0.9);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _toggleTTS() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
    } else {
      await _flutterTts.speak(widget.text);
    }
    setState(() => _isSpeaking = !_isSpeaking);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
          IconButton(
            icon: Icon(_isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _isDark = !_isDark),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(),
          ),
        ],
      ),
      body: Container(
        color: _isDark ? Colors.grey[900] : Colors.white,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: SelectableText(
            widget.text,
            style: TextStyle(
              fontSize: _fontSize,
              height: 1.8,
              color: _isDark ? Colors.white : Colors.black,
            ),
            textDirection: TextDirection.rtl,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleTTS,
        child: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('حجم الخط', style: TextStyle(fontSize: 18)),
              Slider(
                min: 12,
                max: 32,
                value: _fontSize,
                onChanged: (val) {
                  setModalState(() => _fontSize = val);
                  setState(() {});
                },
                onChangeEnd: (_) => _saveSettings(),
              ),
              Text('الخط: ${_fontSize.toStringAsFixed(0)}'),
            ],
          ),
        ),
      ),
    );
  }
}
