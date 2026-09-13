import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Camera barcode scanner screen with tablet support and proper orientation.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController? _controller;
  bool _popped = false;
  bool _flashOn = false;
  bool _isLandscape = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: false,
    );
    
    // Check orientation after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOrientation();
    });
  }

  void _checkOrientation() {
    if (!mounted) return;
    final mediaQuery = MediaQuery.of(context);
    final isTablet = mediaQuery.size.shortestSide >= 600;
    
    if (isTablet) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      setState(() {
        _isLandscape = mediaQuery.orientation == Orientation.landscape;
      });
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      setState(() => _isLandscape = false);
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_popped) return;
    
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode != null && barcode.isNotEmpty) {
      _popped = true;
      HapticFeedback.mediumImpact();
      
      // Show success message then pop
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Scanned: $barcode'),
            ],
          ),
          duration: const Duration(milliseconds: 500),
          backgroundColor: const Color(0xFF1B8A5A),
        ),
      );
      
      // Pop with the barcode after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Navigator.pop(context, barcode);
      });
    }
  }

  void _toggleFlash() {
    setState(() => _flashOn = !_flashOn);
    _controller?.toggleTorch();
  }

  void _switchCamera() {
    _controller?.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isLandscape ? _buildLandscapeLayout(isTablet) : _buildPortraitLayout(isTablet),
      ),
    );
  }

  Widget _buildPortraitLayout(bool isTablet) {
    return Column(
      children: [
        // Top bar
        _buildTopBar(),
        
        // Scanner area
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(
                controller: _controller!,
                onDetect: _onDetect,
              ),
              _buildOverlay(isTablet),
              _buildInstructions(isTablet),
            ],
          ),
        ),
        
        // Bottom controls
        _buildControls(),
      ],
    );
  }

  Widget _buildLandscapeLayout(bool isTablet) {
    return Row(
      children: [
        // Scanner area (left)
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(
                controller: _controller!,
                onDetect: _onDetect,
              ),
              _buildOverlay(isTablet),
              _buildInstructions(isTablet),
            ],
          ),
        ),
        
        // Controls panel (right)
        Container(
          width: 200,
          color: Colors.black87,
          child: Column(
            children: [
              // Top bar
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Scan',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              // Control buttons
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildControlButton(
                      icon: Icons.flash_on,
                      label: 'Flash',
                      onTap: _toggleFlash,
                      isActive: _flashOn,
                    ),
                    const SizedBox(height: 20),
                    _buildControlButton(
                      icon: Icons.cameraswitch,
                      label: 'Switch',
                      onTap: _switchCamera,
                    ),
                    const SizedBox(height: 20),
                    _buildControlButton(
                      icon: Icons.keyboard,
                      label: 'Manual',
                      onTap: () {
                        Navigator.pop(context, null);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black87,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Scan Barcode',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          IconButton(
            icon: Icon(
              _flashOn ? Icons.flash_on : Icons.flash_off,
              color: _flashOn ? Colors.yellow : Colors.white,
            ),
            onPressed: _toggleFlash,
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: _switchCamera,
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay(bool isTablet) {
    return CustomPaint(
      painter: ScannerOverlay(
        borderColor: const Color(0xFF1B8A5A),
        overlayColor: Colors.black.withOpacity(0.5),
        borderRadius: 12,
        borderLength: isTablet ? 80 : 60,
        borderWidth: 4,
      ),
      size: Size.infinite,
    );
  }

  Widget _buildInstructions(bool isTablet) {
    return Positioned(
      bottom: isTablet ? 60 : 40,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Align barcode within the frame',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black87,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.flash_on,
            label: 'Flash',
            onTap: _toggleFlash,
            isActive: _flashOn,
          ),
          _buildControlButton(
            icon: Icons.cameraswitch,
            label: 'Switch',
            onTap: _switchCamera,
          ),
          _buildControlButton(
            icon: Icons.keyboard,
            label: 'Manual',
            onTap: () {
              Navigator.pop(context, null);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF1B8A5A).withOpacity(0.3) : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? const Color(0xFF1B8A5A) : Colors.white.withOpacity(0.3),
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Custom painter for scanner overlay with cutout
class ScannerOverlay extends CustomPainter {
  final Color borderColor;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;

  ScannerOverlay({
    required this.borderColor,
    required this.overlayColor,
    required this.borderRadius,
    required this.borderLength,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scanArea = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.7,
      height: size.height * 0.5,
    );

    // Draw overlay
    final overlayPaint = Paint()..color = overlayColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);

    // Clear scan area
    final clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..color = Colors.transparent;
    canvas.drawRect(scanArea, clearPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Draw corners
    final path = Path();
    final cornerLength = borderLength;

    // Top-left corner
    path.moveTo(scanArea.left + cornerLength, scanArea.top);
    path.lineTo(scanArea.left, scanArea.top);
    path.lineTo(scanArea.left, scanArea.top + cornerLength);

    // Top-right corner
    path.moveTo(scanArea.right - cornerLength, scanArea.top);
    path.lineTo(scanArea.right, scanArea.top);
    path.lineTo(scanArea.right, scanArea.top + cornerLength);

    // Bottom-right corner
    path.moveTo(scanArea.right - cornerLength, scanArea.bottom);
    path.lineTo(scanArea.right, scanArea.bottom);
    path.lineTo(scanArea.right, scanArea.bottom - cornerLength);

    // Bottom-left corner
    path.moveTo(scanArea.left + cornerLength, scanArea.bottom);
    path.lineTo(scanArea.left, scanArea.bottom);
    path.lineTo(scanArea.left, scanArea.bottom - cornerLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(ScannerOverlay oldDelegate) => false;
}
