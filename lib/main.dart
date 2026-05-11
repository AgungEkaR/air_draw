import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AirDraw',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: AirDrawScreen(cameras: cameras),
    );
  }
}

// Model untuk menyimpan stroke beserta warna dan ketebalan
class DrawnStroke {
  final List<Offset?> points;
  final Color color;
  final double strokeWidth;

  DrawnStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}

class AirDrawScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const AirDrawScreen({super.key, required this.cameras});

  @override
  State<AirDrawScreen> createState() => _AirDrawScreenState();
}

class _AirDrawScreenState extends State<AirDrawScreen> {
  HandLandmarkerPlugin? _plugin;
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isDetecting = false;

  // Drawing
  List<DrawnStroke> _strokes = [];
  Color _selectedColor = Colors.blue;
  double _strokeWidth = 4.0;
  bool _isDrawing = false;
  Offset? _lastPoint;
  Offset? _smoothedPoint;

  // Spike filter
  final List<Offset> _recentPoints = [];
  static const int _maxRecentPoints = 5;
  static const double _spikeThreshold = 150.0;

  final List<Color> _colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.white,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final frontCamera = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _plugin = HandLandmarkerPlugin.create(
      numHands: 1,
      minHandDetectionConfidence: 0.5,
      delegate: HandLandmarkerDelegate.gpu,
    );

    await _controller!.initialize();
    await _controller!.startImageStream(_processCameraImage);

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  bool _isSpike(Offset newPoint) {
    if (_recentPoints.isEmpty) return false;
    final distance = (newPoint - _recentPoints.last).distance;
    return distance > _spikeThreshold;
  }

  void _startNewStroke() {
    _strokes.add(DrawnStroke(
      points: [],
      color: _selectedColor,
      strokeWidth: _strokeWidth,
    ));
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting || !_isInitialized || _plugin == null) return;
    _isDetecting = true;

    try {
      final hands = _plugin!.detect(
        image,
        _controller!.description.sensorOrientation,
      );

      if (mounted && hands.isNotEmpty) {
        final hand = hands.first;
        final indexTip = hand.landmarks[8];
        final screenSize = MediaQuery.of(context).size;

        final rawX = (1 - indexTip.y) * screenSize.width;
        final rawY = (1 - indexTip.x) * screenSize.height;
        final newPoint = Offset(rawX, rawY);

        if (_isSpike(newPoint)) {
          _isDetecting = false;
          return;
        }

        _recentPoints.add(newPoint);
        if (_recentPoints.length > _maxRecentPoints) {
          _recentPoints.removeAt(0);
        }

        final smoothed = _smoothedPoint == null
            ? newPoint
            : Offset(
                _smoothedPoint!.dx * 0.65 + newPoint.dx * 0.35,
                _smoothedPoint!.dy * 0.65 + newPoint.dy * 0.35,
              );

        setState(() {
          _smoothedPoint = smoothed;
          _lastPoint = smoothed;
          if (_isDrawing) {
            if (_strokes.isEmpty) _startNewStroke();
            _strokes.last.points.add(smoothed);
          }
        });
      } else if (mounted && hands.isEmpty) {
        setState(() {
          _lastPoint = null;
          _smoothedPoint = null;
          _recentPoints.clear();
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  void _clearCanvas() => setState(() => _strokes = []);

  void _undoLastStroke() {
    setState(() {
      if (_strokes.isNotEmpty) _strokes.removeLast();
    });
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _plugin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_isInitialized && _controller != null)
            SizedBox.expand(
              child: CameraPreview(_controller!),
            ),

          // Drawing canvas
          GestureDetector(
            onPanStart: (_) {
              setState(() {
                _isDrawing = true;
                _startNewStroke();
              });
            },
            onPanEnd: (_) {
              setState(() => _isDrawing = false);
            },
            child: CustomPaint(
              painter: DrawingPainter(strokes: _strokes),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Finger cursor
          if (_lastPoint != null)
            Positioned(
              left: _lastPoint!.dx - 14,
              top: _lastPoint!.dy - 14,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _isDrawing
                      ? _selectedColor.withOpacity(0.8)
                      : Colors.white.withOpacity(0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _isDrawing
                          ? _selectedColor.withOpacity(0.6)
                          : Colors.white.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),

          // Top bar
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '✋ AirDraw',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 4)
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTapDown: (_) {
                          setState(() {
                            _isDrawing = true;
                            _startNewStroke();
                          });
                        },
                        onTapUp: (_) {
                          setState(() => _isDrawing = false);
                        },
                        onTapCancel: () {
                          setState(() => _isDrawing = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isDrawing
                                ? _selectedColor
                                : Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isDrawing
                                  ? _selectedColor
                                  : Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _isDrawing ? '✏️ Drawing' : '✋ Hold to Draw',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildIconBtn(Icons.undo, _undoLastStroke),
                      _buildIconBtn(Icons.delete_outline, _clearCanvas),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _colors.map((color) {
                      final isSelected = _selectedColor == color;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedColor = color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 38 : 28,
                          height: isSelected ? 38 : 28,
                          margin:
                              const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.6),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.line_weight,
                          color: Colors.white, size: 18),
                      Expanded(
                        child: Slider(
                          value: _strokeWidth,
                          min: 2,
                          max: 20,
                          activeColor: _selectedColor,
                          inactiveColor: Colors.white.withOpacity(0.3),
                          onChanged: (val) =>
                              setState(() => _strokeWidth = val),
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          _strokeWidth.toStringAsFixed(0),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Loading
          if (!_isInitialized)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Loading AI model...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Initializing hand tracking',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawnStroke> strokes;

  DrawingPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < stroke.points.length - 1; i++) {
        if (stroke.points[i] != null && stroke.points[i + 1] != null) {
          canvas.drawLine(stroke.points[i]!, stroke.points[i + 1]!, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}