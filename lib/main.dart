import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const RecycleDetectionApp());
}

class RecycleDetectionApp extends StatelessWidget {
  const RecycleDetectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recycle Detection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: TextTheme(
          headlineLarge: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: 32,
          ),
          headlineSmall: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
          bodyMedium: GoogleFonts.poppins(fontSize: 16),
          bodySmall: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
        ),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4CAF50),
          secondary: Color(0xFF009688),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

//
// ---------------- SPLASH SCREEN ----------------
//
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) => const HomePage(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade700, Colors.green.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Icon(Icons.eco, size: 100, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: const [
                      Text(
                        "Recycle Detection",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Making waste detection easy ♻️",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          letterSpacing: 1.1,
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
  }
}

//
// ---------------- HOME PAGE ----------------
//
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() => _isLoading = true);

      final result = await _detectWaste(pickedFile.path);

      // Navigate and wait until the user comes back
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              ResultPage(imageFile: File(pickedFile.path), detections: result),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );

      // Reset loading only after user returns
      setState(() => _isLoading = false);
    }
  }

  Future<List<dynamic>> _detectWaste(String imagePath) async {
    final url = Uri.parse(
      "https://j8yqp1c2o0.execute-api.ap-southeast-1.amazonaws.com/detect",
    );

    final bytes = await File(imagePath).readAsBytes();

    // Decode image to get real width/height
    final image = await decodeImageFromList(bytes);
    final imgWidth = image.width.toDouble();
    final imgHeight = image.height.toDouble();

    final base64Image = base64Encode(bytes);

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"image": base64Image}),
    );

    if (response.statusCode == 200) {
      print("API Response: ${response.body}");
      final decoded = jsonDecode(response.body);

      if (decoded is Map && decoded.containsKey("predictions")) {
        final preds = decoded["predictions"] as List;

        return preds
            .map((p) {
              final conf = (p["confidence"] as num).toDouble();
              if (conf < 0.1) return null;

              final bbox = p["bbox"] as List;
              final xmin = (bbox[0] as num).toDouble();
              final ymin = (bbox[1] as num).toDouble();
              final xmax = (bbox[2] as num).toDouble();
              final ymax = (bbox[3] as num).toDouble();

              return {
                "x": xmin / imgWidth,
                "y": ymin / imgHeight,
                "w": (xmax - xmin) / imgWidth,
                "h": (ymax - ymin) / imgHeight,
                "label": p["class"],
                "confidence": conf,
              };
            })
            .where((e) => e != null)
            .toList();
      }
    } else {
      print("Error: ${response.statusCode} ${response.body}");
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "♻️ Recycle/Waste Detection",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black12,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            )
          : Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE8F5E9), Color(0xFFF5F5F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.eco,
                        size: 110,
                        color: Color(0xFF4CAF50),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Identify recyclables instantly!",
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Snap or scan in real-time to check recyclability.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 40),

                      // ✅ Buttons
                      _fancyButton(
                        icon: Icons.camera_alt,
                        color: const Color(0xFF4CAF50),
                        text: "Capture with Camera",
                        onTap: () => _pickImage(ImageSource.camera),
                      ),
                      const SizedBox(height: 20),
                      _fancyButton(
                        icon: Icons.photo_library,
                        color: const Color(0xFF009688),
                        text: "Upload from Gallery",
                        onTap: () => _pickImage(ImageSource.gallery),
                      ),
                      const SizedBox(height: 20),
                      _fancyButton(
                        icon: Icons.videocam,
                        color: Colors.deepPurple,
                        text: "Live Scan Mode",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LiveScanPage(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _fancyButton(
                        icon: Icons.map,
                        color: Colors.blueAccent,
                        text: "Find Nearest Bin",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MapSample(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _fancyButton({
    required IconData icon,
    required Color color,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.black38,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

//
// ---------------- LIVE SCAN PAGE ----------------
//
class LiveScanPage extends StatefulWidget {
  const LiveScanPage({super.key});

  @override
  State<LiveScanPage> createState() => _LiveScanPageState();
}

class _LiveScanPageState extends State<LiveScanPage> {
  CameraController? _controller;
  bool _isDetecting = false;
  List<dynamic> _detections = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    _controller = CameraController(cameras[0], ResolutionPreset.medium);
    await _controller!.initialize();
    setState(() {});

    // Capture frame every 3 seconds and send to API
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isDetecting && _controller!.value.isInitialized) {
        _isDetecting = true;
        try {
          final detections = await _captureAndDetect();
          if (mounted) {
            setState(() => _detections = detections);
          }
        } finally {
          _isDetecting = false;
        }
      }
    });
  }

  Future<List<dynamic>> _captureAndDetect() async {
    try {
      final picture = await _controller!.takePicture();
      final bytes = await File(picture.path).readAsBytes();

      // ✅ Decode actual captured dimensions
      final decodedImg = await decodeImageFromList(bytes);
      final imgWidth = decodedImg.width.toDouble();
      final imgHeight = decodedImg.height.toDouble();

      final base64Image = base64Encode(bytes);
      final url = Uri.parse(
        "https://j8yqp1c2o0.execute-api.ap-southeast-1.amazonaws.com/detect",
      );

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"image": base64Image}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey("predictions")) {
          final preds = decoded["predictions"] as List;

          return preds
              .map((p) {
                final conf = (p["confidence"] as num).toDouble();
                if (conf < 0.1) return null;

                final bbox = p["bbox"] as List;
                final xmin = (bbox[0] as num).toDouble();
                final ymin = (bbox[1] as num).toDouble();
                final xmax = (bbox[2] as num).toDouble();
                final ymax = (bbox[3] as num).toDouble();

                return {
                  "x": xmin / imgWidth,
                  "y": ymin / imgHeight,
                  "w": (xmax - xmin) / imgWidth,
                  "h": (ymax - ymin) / imgHeight,
                  "label": p["class"],
                  "confidence": conf,
                };
              })
              .where((e) => e != null)
              .toList();
        }
      }
    } catch (e) {
      print("LiveScan Exception: $e");
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "♻️ Live Waste Detection",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black12,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ✅ Match ResultPage: use BoxFit.contain instead of CameraPreview (cover)
          Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _controller!.value.previewSize!.height, // 👈 swap
                height: _controller!.value.previewSize!.width, // 👈 swap
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          // ✅ Same painter logic now aligns correctly
          CustomPaint(
            painter: BoundingBoxPainter(
              _detections,
              previewSize: _controller!.value.previewSize,
            ),
            child: Container(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

//
// ---------------- BOUNDING BOX PAINTER ----------------
//
class BoundingBoxPainter extends CustomPainter {
  final List<dynamic> detections;
  final ui.Image? image;
  final Size? previewSize;

  BoundingBoxPainter(this.detections, {this.image, this.previewSize});

  // ✅ Map detected label → bin color
  Color _getColor(String label) {
    switch (label.toLowerCase()) {
      case "cardboard":
      case "paper":
        return Colors.blueAccent; // 🟦 Paper/Cardboard bin
      case "glass":
        return Colors.brown; // 🟫 Glass bin
      case "plastic":
      case "metal":
      case "aluminum":
      case "tin":
        return Colors.orange; // 🟧 Plastic/Metal bin
      case "garden_waste":
      case "food_waste":
      case "organic":
        return Colors.green; // 🟩 Organic bin
      case "general_waste":
      case "trash":
      case "non_recyclable":
        return Colors.black; // ⚫ General waste bin
      default:
        return Colors.tealAccent; // fallback
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    double imgW, imgH;
    if (image != null) {
      imgW = image!.width.toDouble();
      imgH = image!.height.toDouble();
    } else if (previewSize != null) {
      imgW = previewSize!.height.toDouble();
      imgH = previewSize!.width.toDouble();
    } else {
      return;
    }

    final imgRatio = imgW / imgH;
    final canvasRatio = size.width / size.height;

    double scale;
    double dx = 0;
    double dy = 0;

    if (imgRatio > canvasRatio) {
      scale = size.width / imgW;
      dy = (size.height - imgH * scale) / 2;
    } else {
      scale = size.height / imgH;
      dx = (size.width - imgW * scale) / 2;
    }

    for (var det in detections) {
      final label = det['label'].toString();
      final color = _getColor(label);

      final paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      final rect = Rect.fromLTWH(
        dx + det['x'] * imgW * scale,
        dy + det['y'] * imgH * scale,
        det['w'] * imgW * scale,
        det['h'] * imgH * scale,
      );
      canvas.drawRect(rect, paint);

      final textStyle = ui.TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      );

      final builder = ui.ParagraphBuilder(ui.ParagraphStyle())
        ..pushStyle(textStyle)
        ..addText(label);
      final paragraph = builder.build()
        ..layout(const ui.ParagraphConstraints(width: 140));
      canvas.drawParagraph(paragraph, Offset(rect.left, rect.top - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

//
// ---------------- RESULT PAGE ----------------
//
class ResultPage extends StatelessWidget {
  final File imageFile;
  final List<dynamic> detections;

  const ResultPage({
    super.key,
    required this.imageFile,
    required this.detections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Detection Results",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black12,
      ),
      body: detections.isEmpty
          ? _noDetectionsView(context) // ✅ Show message when no predictions
          : Column(
              children: [
                Expanded(
                  child: FutureBuilder<ui.Image>(
                    future: _loadUiImage(imageFile),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.file(imageFile, fit: BoxFit.contain),
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: BoundingBoxPainter(
                                detections,
                                image: snapshot.data,
                              ),
                              child: Container(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  /// ✅ No detections UI
  Widget _noDetectionsView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 80,
              color: Colors.orange,
            ),
            const SizedBox(height: 20),
            const Text(
              "No objects detected ❌",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Try recapturing the object with better lighting or angle.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // go back to capture again
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text("Retake Photo"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to load ui.Image from File
  Future<ui.Image> _loadUiImage(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

/// ========== Bin Finder (Google Maps) ==========

class MapSample extends StatefulWidget {
  const MapSample({super.key});

  @override
  State<MapSample> createState() => MapSampleState();
}

class BinWithDistance {
  final Marker marker;
  final double distance;

  BinWithDistance({required this.marker, required this.distance});
}

const String apiUrl =
    "https://g723vjo5ua.execute-api.ap-southeast-1.amazonaws.com/prod/bins";

Future<List<Map<String, dynamic>>> fetchBins() async {
  final response = await http.get(Uri.parse(apiUrl));

  if (response.statusCode == 200) {
    final Map<String, dynamic> outerResponse = jsonDecode(response.body);
    final Map<String, dynamic> innerBody = jsonDecode(outerResponse['body']);
    final List bins = innerBody['bins'];
    return bins.cast<Map<String, dynamic>>();
  } else {
    throw Exception("Failed to load bins");
  }
}

class MapSampleState extends State<MapSample> {
  late GoogleMapController mapController;
  List<Marker> _markers = [];
  Position? _currentPosition;
  bool _isLoadingLocation = false;

  Future<void> _loadMarkers() async {
    try {
      final bins = await fetchBins();

      setState(() {
        _markers = bins.map((bin) {
          final lat = (bin['latitude'] as num).toDouble();
          final lng = (bin['longitude'] as num).toDouble();
          final markerId = bin['id'];
          final binName = bin['name'];

          return Marker(
            markerId: MarkerId(markerId),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: binName,
              snippet: 'Tap here to navigate',
              onTap: () => _showNavigationOptions(binName, LatLng(lat, lng)),
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          );
        }).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading bins: $e")));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    _checkLocationPermission();
  }

  // Check and request location permission on init
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, prompt user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location services'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are permanently denied. Enable in settings.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // If we have permission, get current location
    _getCurrentLocation();
  }

  // Custom function to handle location button tap
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      // Animate camera to current location
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15.0,
          ),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _showNavigationOptions(
    String binName,
    LatLng destination,
  ) async {
    try {
      Position currentPosition;
      if (_currentPosition != null) {
        currentPosition = _currentPosition!;
      } else {
        currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(Icons.recycling, size: 48, color: Colors.green[700]),
              const SizedBox(height: 16),
              Text(
                binName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Open in Google Maps?',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _launchMaps(currentPosition, destination);
                      },
                      icon: const Icon(Icons.navigation),
                      label: const Text('Navigate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: ${e.toString()}')),
      );
    }
  }

  Future<void> _findAndShowNearestBins() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied.')),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permissions are permanently denied. Enable them in settings.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Finding your location and the nearest bins...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      Position currentPosition;
      if (_currentPosition != null) {
        currentPosition = _currentPosition!;
      } else {
        currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _currentPosition = currentPosition;
        });
      }

      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(currentPosition.latitude, currentPosition.longitude),
            zoom: 15.0,
          ),
        ),
      );

      List<BinWithDistance> binsWithDistances = [];
      for (final marker in _markers) {
        final distance = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          marker.position.latitude,
          marker.position.longitude,
        );
        binsWithDistances.add(
          BinWithDistance(marker: marker, distance: distance),
        );
      }

      binsWithDistances.sort((a, b) => a.distance.compareTo(b.distance));

      final List<BinWithDistance> nearestBins = binsWithDistances
          .take(5)
          .toList();

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (nearestBins.isNotEmpty) {
        _showNearestBinsSheet(nearestBins, currentPosition);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No recycle bins found.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  void _showNearestBinsSheet(List<BinWithDistance> bins, Position origin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.25,
          maxChildSize: 0.75,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fixed header
                  Container(
                    padding: const EdgeInsets.only(top: 20, bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.near_me, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            const Text(
                              'Nearest Recycle Bins',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Scrollable list
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: bins.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final bin = bins[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            bin.marker.infoWindow.title ?? 'Recycle Bin',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '${_formatDistance(bin.distance)} away',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.directions,
                              color: Colors.green[700],
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _launchMaps(origin, bin.marker.position);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(2)} km';
    }
  }

  Future<void> _launchMaps(Position origin, LatLng destination) async {
    final String googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&travelmode=driving';

    final Uri uri = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps for navigation.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recycle Bin Map"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Row(
                    children: [
                      Icon(Icons.help_outline, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      const Text("How to Use"),
                    ],
                  ),
                  content: const Text(
                    "• Tap on any green marker to see bin details\n"
                    "• Tap the info popup to navigate\n"
                    "• Use 'Find Nearest Bins' button to see the 5 closest bins\n"
                    "• Tap location button to center the map on your position",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Got it",
                        style: TextStyle(color: Colors.green[700]),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(3.1390, 101.6869),
              zoom: 12.0,
            ),
            markers: Set.from(_markers),
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Disable default button
            zoomControlsEnabled: false, // Optional: disable zoom controls
          ),
          // Custom location button
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
              child: _isLoadingLocation
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.green[700]!,
                        ),
                      ),
                    )
                  : Icon(Icons.my_location, color: Colors.green[700]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _findAndShowNearestBins,
        label: const Text('Find Nearest Bins'),
        icon: const Icon(Icons.search),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
