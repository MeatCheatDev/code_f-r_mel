import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as img;

import 'package:camera/camera.dart';
import 'package:flutter/Material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../business_logic/state_managment/blocs/manage_food/manage_stock/add_stock_scan/food_scan_bloc.dart';

class MHDScannerPage extends StatefulWidget {
  const MHDScannerPage({super.key, required this.pageController});
  final PageController pageController;

  @override
  State<MHDScannerPage> createState() => _MHDScannerPageState();
}
///Hier ist das drama dann vollendet. ich habe ABSOLUT keine AHNUNG was davon jetzt eigentlich ein Bloc sein sollte, jedenfalls sind hier viel zu viele Funktionen
///das kann so niemals normal sein. Außerdem stört mich, dass hier ja erneut die Kmaera verwendet wird. Ich habe es nicht geschafft DIESELBE kamera die auch für den barcode scanner
///hier wieder zu verwenden. Sprich sie nie zu schlechen den CameraController sondern zu passen und hier weiter zu verwenden. so wäre es evtl etwas flüssiger (?) I guess.
///aucb ist mir kein besserer WorkAround eignefallen als diese alle 120 ms oder was das jetzt war ein foto zu machen, dann die RegEx drüber laufen zu lassen und das nächste zu machen
///ich finde aber an sich ist der workflow mit den Foto machen eigentlich recht robust. Nur die Funktionen hier im UI stören mich und dieses laggy verhalten...
class _MHDScannerPageState extends State<MHDScannerPage> {
  late CameraController _cameraController;
  late StreamController<String> _textStreamController;
  bool _isDetecting = false;
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _mhdDetected = false;
  Timer? _scanTimer;
  String? _detectedMHD;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _textStreamController = StreamController<String>();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _textStreamController.close();
    _textRecognizer.close();
    _scanTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _cameraController = CameraController(firstCamera, ResolutionPreset.medium, enableAudio: false);
    await _cameraController.initialize();

    if (!mounted) return;

    setState(() {
      _isCameraInitialized = true;
    });

    _startImageProcessing();
  }

  void _startImageProcessing() {
    _scanTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) async {
      if (!_isDetecting && !_mhdDetected) {
        // Stoppt, wenn MHD gefunden wurde
        _isDetecting = true;
        await _captureAndRecognize();
        _isDetecting = false;
      } else if (_mhdDetected) {
        _scanTimer?.cancel(); // Stoppe den Timer
        if (kDebugMode) {
          print("MHD erkannt! Suche gestoppt.");
        }
      }
    });
  }

  void _restartScanning() {
    setState(() {
      _mhdDetected = false;
      _detectedMHD = null;
    });
    _startImageProcessing(); // Startet die Erkennung neu
  }

  Future<File> _cropImageToBoundingBox(File imageFile) async {
    _deleteOldTempFiles();

    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) return imageFile; // Falls kein Bild erkannt wurde, Original zurückgeben

    // Kleinere Bounding Box definieren
    int centerX = image.width ~/ 2;
    int centerY = image.height ~/ 2;
    int boxWidth = 205; // Muss mit ScanOverlay.width übereinstimmen
    int boxHeight = 50; // Muss mit ScanOverlay.height übereinstimmen

    img.Image cropped = img.copyCrop(image, x: centerX - boxWidth ~/ 2, y: centerY - boxHeight ~/ 2, width: boxWidth, height: boxHeight);

    // Speichere das zugeschnittene Bild temporär
    final tempDir = Directory.systemTemp;
    final croppedFile = File('${tempDir.path}/cropped.png')..writeAsBytesSync(img.encodePng(cropped));

    return croppedFile;
  }

  Future<void> _captureAndRecognize() async {
    try {
      final XFile imageFile = await _cameraController.takePicture();
      final File croppedImage = await _cropImageToBoundingBox(File(imageFile.path)); // Bild zuschneiden

      final InputImage inputImage = InputImage.fromFilePath(croppedImage.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      String fullText = recognizedText.text;

      // Extrahiere das erkannte MHD
      String? detectedMHD = _extractMHD(fullText);
      bool isMHD = detectedMHD != null;

      ///Auch hier wieder build context einfach völlig wild verwendet
      _textStreamController.add(fullText);
      setState(() {
        _mhdDetected = isMHD;
        context.read<FoodScanBloc>().add(AddMhdToProductEvent(parseDate(detectedMHD!)));
        widget.pageController.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeIn);

        _detectedMHD = detectedMHD;
      });

      // Optional: Lösche temporäres Bild, um Speicher zu sparen
      File(imageFile.path).delete();
    } catch (e) {
      if (kDebugMode) {
        print("Error during OCR: $e");
      }
    }
  }

  DateTime parseDate(String input) {
    // Entferne überflüssige Leerzeichen
    input = input.trim();

    // 1. Format: "MM/YYYY" (zwei Teile, getrennt durch "/")
    if (RegExp(r'^\s*\d{1,2}\s*\/\s*\d{2,4}\s*$').hasMatch(input)) {
      final parts = input.split('/');
      final month = int.parse(parts[0].trim());
      var year = int.parse(parts[1].trim());
      if (year < 100) {
        year += 2000;
      }
      return DateTime(year, month);
    }

    // 2. Format: Numerisches Datum mit Tag, Monat, Jahr
    // z.B. "DD.MM.YYYY", "DD-MM-YYYY" oder "DD/MM/YYYY"
    if (RegExp(r'^\s*\d{1,2}\s*[-./]\s*\d{1,2}\s*[-./]\s*\d{2,4}\s*$').hasMatch(input)) {
      // Ermittle das Trennzeichen (z. B. Punkt, Bindestrich oder Schrägstrich)
      final separatorMatch = RegExp(r'[-./]').firstMatch(input);
      final separator = separatorMatch?.group(0) ?? '/';
      final parts = input.split(separator);
      final day = int.parse(parts[0].trim());
      final month = int.parse(parts[1].trim());
      var year = int.parse(parts[2].trim());
      if (year < 100) {
        year += 2000;
      }
      return DateTime(year, month, day);
    }

    // 3. Format: Monatsabkürzung, z.B. "NOV. 2025"
    // Hier wird angenommen, dass der Monatsname nicht durch den Cleaning-Schritt verloren geht.
    if (RegExp(r'^(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\.?\s*\d{4}$', caseSensitive: false)
        .hasMatch(input)) {
      // Teile die Eingabe am Leerzeichen
      final parts = input.split(RegExp(r'\s+'));
      // Entferne ggf. den Punkt und wandle in Großbuchstaben um
      final monthStr = parts[0].replaceAll('.', '').toUpperCase();
      final monthMap = {
        'JAN': 1,
        'FEB': 2,
        'MAR': 3,
        'APR': 4,
        'MAY': 5,
        'JUN': 6,
        'JUL': 7,
        'AUG': 8,
        'SEP': 9,
        'OCT': 10,
        'NOV': 11,
        'DEC': 12,
      };
      final month = monthMap[monthStr] ?? 1;
      final year = int.parse(parts[1]);
      return DateTime(year, month);
    }

    // Falls keines der oben genannten Formate passt,
    // versuche die Eingabe direkt zu parsen
    final parsed = DateTime.tryParse(input);
    if (parsed != null) return parsed;

    throw FormatException("Ungültiges Datumsformat: $input");
  }
  void _deleteOldTempFiles() async {
    final tempDir = Directory.systemTemp;
    if (tempDir.existsSync()) {
      tempDir.listSync().forEach((file) {
        if (file is File) {
          file.deleteSync();
        }
      });
    }
  }

  String? _extractMHD(String input) {
    RegExp dateRegex = RegExp(
      // Numerisches Datum: DD.MM.YYYY, DD-MM-YYYY oder DD/MM/YYYY mit optionalen Leerzeichen
      r'(\b(0?[1-9]|[12]\d|3[01])\s*[-./]\s*(0?[1-9]|1[0-2])\s*[-./]\s*(\d{2}|\d{4})\b)|'
      // Format: MM/YYYY (ebenfalls optional um den Schrägstrich)
      r'(\b(0?[1-9]|1[0-2])\s*\/\s*\d{4}\b)|'
      // Format: "NOV. 2025" etc.
      r'(\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\.?\s\d{4}\b)',
      caseSensitive: false,
    );

    // Entfernt alle Zeichen außer Zahlen, Punkt, Schrägstrich und Bindestrich
    input = input.replaceAll(RegExp(r'[^0-9./-]'), ' ');

    Match? match = dateRegex.firstMatch(input);
    return match?.group(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Live MHD Scanner")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: _isCameraInitialized
                ? Stack(
                    children: [
                      ///Die kamera overlay idee kam von mir, chatGpt hat sie umgesetzt ich weiß nicht was ich davon halten soll. Finde es richtig geil aber ka ob das so performant ist
                      ///ohne geht aber nicht denn wenn er innerhalb von 120 ms ein ganzes foto scannen soll haste keine chance. daher nur den kleinen ausschnitt
                      Center(child: CameraPreview(_cameraController)),
                      const Center(child: ScanOverlay()), // Fügt das Overlay über die Kamera hinzu
                    ],
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          Expanded(
            flex: 1,
            child: StreamBuilder<String>(
              stream: _textStreamController.stream,
              builder: (context, snapshot) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_mhdDetected)
                        Column(
                          children: [
                            Text(
                              "MHD identifiziert! ${_detectedMHD ?? ''}",
                              style: TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            ElevatedButton(
                              onPressed: _restartScanning,
                              child: Text("Erneut scannen"),
                            ),

                          ],
                        )
                      else
                        Text(
                          "MHD wird gesucht...",
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ScanOverlay extends StatelessWidget {
  const ScanOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: Colors.black.withOpacity(0.5), // Abdunklung des gesamten Bildes
        ),
        Center(
          child: Container(
            width: 205, // Verringere die Breite (war 250)
            height: 50, // Verringere die Höhe (war 80)
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 3), // Grüne Umrandung
              color: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }
}
