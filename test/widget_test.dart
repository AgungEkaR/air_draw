import 'dart:async';
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

class AirDrawScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const AirDrawScreen({super.key, required this.cameras});

  @override
  State<AirDrawScreen> createState() => _AirDrawScreenState();
}

class _AirDrawScreenState extends State<AirDrawScreen> {
  late CameraController _cameraController;
  HandLandmarker? _handLandmarker;
  bool _isProcessing = false;
  bool _isCameraReady = false;

  List<List<Offset?>> _strokes = [[]];
  Color _selectedColor = Colors.blue;
  double _strokeWidth = 4.0;
  bool _isDrawing = false;
  Offset? _lastPoint;

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
    _initCamera();
    _initHandLandmarker();
  }

  Future<void> _initCamera() async {
    final frontCamera = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController.initialize();

    if (mounted) {
      setState(() => _isCameraReady = true);
      _cameraController.startImageStream(_processCameraImage);
    }
  }

  Future<void> _initHandLandmarker() async {
    _handLandmarker = await HandLandmarker.create(
      modelPath: 'assets/models/hand_landmarker.task',
      numHands: 1,
      minHandDetectionConfidence: 0.5,
      minHandPresenceConfidence: 0.5,
      minTrackingConfidence: 0.5,
    );
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || _handLandmarker == null) return;
    _isProcessing = true;

    try {
      final results = await _handLandmarker!.detect(image);

      if (results.isNotEmpty && mounted) {
        final hand = results.first;
        final indexTip = hand.landmarks[8];

        final screenSize = MediaQuery.of(context).size;

        final x = (1 - indexTip.x) * screenSize.width;
        final y = indexTip.y * screenSize.height;
        final point = Offset(x, y);

        setState(() {
          if (_isDrawing) {
            _strokes.last.add(point);
          }
          _lastPoint = point;
        });
      } else if (mounted) {
        setState(() => _lastPoint = null);
      }
    } catch (_) {}

    _isProcessing = false;
  }

  void _clearCanvas() {
    setState(() {
      _strokes = [[]];
    });
  }

  void _undoLastStroke() {
    if (_strokes.length > 1) {
      setState(() => _strokes.removeLast());
    } else {
      setState(() => _strokes = [[]]);
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _handLandmarker?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_isCameraReady)
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scale(-1.0, 1.0),
              child: SizedBox.expand(
                child: CameraPreview(_cameraController),
              ),
            ),

          // Drawing canvas
          GestureDetector(
            onPanStart: (_) {
              setState(() {
                _isDrawing = true;
                _strokes.add([]);
              });
            },
            onPanEnd: (_) {
              setState(() {
                _isDrawing = false;
                _strokes.add([]);
              });
            },
            child: CustomPaint(
              painter: DrawingPainter(
                strokes: _strokes,
                color: _selectedColor,
                strokeWidth: _strokeWidth,
              ),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Finger cursor
          if (_lastPoint != null)
            Positioned(
              left: _lastPoint!.dx - 12,
              top: _lastPoint!.dy - 12,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _isDrawing
                      ? _selectedColor.withOpacity(0.7)
                      : Colors.white.withOpacity(0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
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
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTapDown: (_) =>
                            setState(() => _isDrawing = true),
                        onTapUp: (_) =>
                            setState(() => _isDrawing = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isDrawing
                                ? _selectedColor
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isDrawing ? '✏️ Drawing' : '✋ Hold to Draw',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.undo, color: Colors.white),
                        onPressed: _undoLastStroke,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white),
                        onPressed: _clearCanvas,
                      ),
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
              padding: const EdgeInsets.all(16),
              color: Colors.black.withOpacity(0.6),
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
                        child: Container(
                          width: isSelected ? 36 : 28,
                          height: isSelected ? 36 : 28,
                          margin:
                              const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Colors.white, width: 3)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.line_weight,
                          color: Colors.white, size: 20),
                      Expanded(
                        child: Slider(
                          value: _strokeWidth,
                          min: 2,
                          max: 20,
                          activeColor: _selectedColor,
                          onChanged: (val) =>
                              setState(() => _strokeWidth = val),
                        ),
                      ),
                      Text(
                        _strokeWidth.toStringAsFixed(0),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Loading
          if (!_isCameraReady)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Loading AI model...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<List<Offset?>> strokes;
  final Color color;
  final double strokeWidth;

  DrawingPainter({
    required this.strokes,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        if (stroke[i] != null && stroke[i + 1] != null) {
          canvas.drawLine(stroke[i]!, stroke[i + 1]!, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}