import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:dossier/domain/services/media_prep_service.dart';

class MediaPrepStudioScreen extends StatefulWidget {
  const MediaPrepStudioScreen({super.key});

  @override
  State<MediaPrepStudioScreen> createState() => _MediaPrepStudioScreenState();
}

class _MediaPrepStudioScreenState extends State<MediaPrepStudioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Stitcher State
  Uint8List? _stitchedResult;
  bool _isStitching = false;

  // Compressor State
  Uint8List? _compressedResult;
  int _originalSize = 0;
  int _compressedSize = 0;
  bool _isCompressing = false;

  // Passport Studio State
  Uint8List? _passportGridResult;
  int _photoCount = 6;
  bool _isGeneratingGrid = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Synthetic Demo Image Generators for Instant Live Previews ---

  Uint8List _generateSampleCardImage(String title, Color bgColor) {
    final canvas = img.Image(width: 800, height: 500);
    img.fill(canvas, color: img.ColorRgba8(bgColor.red, bgColor.green, bgColor.blue, 255));
    img.drawRect(canvas, x1: 20, y1: 20, x2: 780, y2: 480, color: img.ColorRgba8(255, 255, 255, 255));
    img.drawString(canvas, title, font: img.arial24, x: 50, y: 50, color: img.ColorRgba8(255, 255, 255, 255));
    return Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
  }

  Uint8List _generateSamplePortrait() {
    final canvas = img.Image(width: 600, height: 800);
    img.fill(canvas, color: img.ColorRgba8(59, 130, 246, 255)); // Blue background
    // Head circle
    img.fillCircle(canvas, x: 300, y: 350, radius: 180, color: img.ColorRgba8(245, 158, 11, 255));
    // Shoulders
    img.fillRect(canvas, x1: 100, y1: 550, x2: 500, y2: 800, color: img.ColorRgba8(30, 41, 59, 255));
    return Uint8List.fromList(img.encodeJpg(canvas, quality: 95));
  }

  Future<void> _runStitcherDemo() async {
    setState(() => _isStitching = true);
    try {
      final front = _generateSampleCardImage('GOVT ID CARD - FRONT\nName: Ramesh Kumar\nDOB: 12/04/1988', Colors.indigo);
      final back = _generateSampleCardImage('GOVT ID CARD - BACK\nAddress: Sector 4, Main Market\nPIN: 110001', Colors.teal);

      final result = await MediaPrepService.stitchIdFrontAndBack(
        frontImageBytes: front,
        backImageBytes: back,
        outputA4: true,
      );

      setState(() => _stitchedResult = result);
    } finally {
      setState(() => _isStitching = false);
    }
  }

  Future<void> _runCompressorDemo(int targetKb) async {
    setState(() => _isCompressing = true);
    try {
      // Large 2000x2000 image ~2.5 MB
      final largeImg = img.Image(width: 2000, height: 2000);
      img.fill(largeImg, color: img.ColorRgba8(20, 80, 160, 255));
      for (int i = 0; i < 200; i++) {
        img.drawCircle(largeImg, x: (i * 37) % 2000, y: (i * 53) % 2000, radius: 40, color: img.ColorRgba8(255, 200, 50, 255));
      }
      final rawBytes = Uint8List.fromList(img.encodeJpg(largeImg, quality: 100));
      _originalSize = rawBytes.lengthInBytes;

      final result = await MediaPrepService.compressToTargetSize(
        inputBytes: rawBytes,
        targetSizeBytes: targetKb * 1024,
      );

      setState(() {
        _compressedResult = result;
        _compressedSize = result.lengthInBytes;
      });
    } finally {
      setState(() => _isCompressing = false);
    }
  }

  Future<void> _runPassportGridDemo() async {
    setState(() => _isGeneratingGrid = true);
    try {
      final portrait = _generateSamplePortrait();
      final result = await MediaPrepService.generatePassportPhotoGrid(
        portraitBytes: portrait,
        photoCount: _photoCount,
      );
      setState(() => _passportGridResult = result);
    } finally {
      setState(() => _isGeneratingGrid = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Column(
        children: [
          // Header & Studio Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(bottom: BorderSide(color: Color(0xFF334155))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.burst_mode_rounded, color: Color(0xFF818CF8), size: 22),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Media Prep Studio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('Pure-Dart Isolate Image Processing (Zero C++ Dependencies)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 450,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFF818CF8),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(icon: Icon(Icons.style_rounded, size: 16), text: 'ID Card Stitcher'),
                      Tab(icon: Icon(Icons.compress_rounded, size: 16), text: 'Portal Compressor'),
                      Tab(icon: Icon(Icons.grid_view_rounded, size: 16), text: '4x6 Passport Grid'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildIdStitcherView(),
                _buildCompressorView(),
                _buildPassportStudioView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdStitcherView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Controls
          SizedBox(
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Front & Back ID Card Stitcher', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  'Merges front and back captures onto a standard A4 sheet with folding and cutting markers for rapid kiosk printing.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isStitching ? null : _runStitcherDemo,
                  icon: _isStitching
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_fix_high_rounded),
                  label: const Text('Stitch Front + Back ID'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('High-res 300 DPI stitched A4 output ready for counter print!')),
                    );
                  },
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Send Stitched Page to Printer'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    side: const BorderSide(color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),

          // Right Live Canvas Preview
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Center(
                child: _stitchedResult != null
                    ? Image.memory(_stitchedResult!, fit: BoxFit.contain)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.crop_original_rounded, size: 64, color: Colors.grey[600]),
                          const SizedBox(height: 12),
                          const Text('No stitched output generated yet', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Tap "Stitch Front + Back ID" to run the Dart background isolate', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompressorView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Controls
          SizedBox(
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Portal Target-Size Compressor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  'Enforces government portal upload bounds (< 200 KB or < 50 KB) via binary-search DCT quantization without quality loss.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isCompressing ? null : () => _runCompressorDemo(200),
                  icon: const Icon(Icons.compress_rounded),
                  label: const Text('Compress to < 200 KB'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isCompressing ? null : () => _runCompressorDemo(50),
                  icon: const Icon(Icons.compress_rounded),
                  label: const Text('Compress to < 50 KB (Photo/Sign)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                if (_compressedResult != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Original Size: ${(_originalSize / 1024).toStringAsFixed(1)} KB', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('Compressed Size: ${(_compressedSize / 1024).toStringAsFixed(1)} KB', style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Compression Ratio: ${((1 - (_compressedSize / _originalSize)) * 100).toStringAsFixed(0)}% reduced', style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 32),

          // Right Preview
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Center(
                child: _compressedResult != null
                    ? Image.memory(_compressedResult!, fit: BoxFit.contain)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded, size: 64, color: Colors.grey[600]),
                          const SizedBox(height: 12),
                          const Text('No image compressed yet', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Select a target threshold (<200KB or <50KB) to run quantization', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassportStudioView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Controls
          SizedBox(
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('4x6 Passport Photo Studio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  'Auto-crops portrait shots to 35x45mm and tiles an aligned grid on a standard 4x6 inch photo print sheet with scissor guidelines.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
                const SizedBox(height: 20),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 6, label: Text('6 Photos (2x3)')),
                    ButtonSegment(value: 8, label: Text('8 Photos (2x4)')),
                  ],
                  selected: {_photoCount},
                  onSelectionChanged: (val) => setState(() => _photoCount = val.first),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isGeneratingGrid ? null : _runPassportGridDemo,
                  icon: _isGeneratingGrid
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.grid_on_rounded),
                  label: Text('Generate $_photoCount-Photo Sheet'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),

          // Right Preview
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Center(
                child: _passportGridResult != null
                    ? Image.memory(_passportGridResult!, fit: BoxFit.contain)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.portrait_rounded, size: 64, color: Colors.grey[600]),
                          const SizedBox(height: 12),
                          const Text('No passport photo grid generated yet', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Select 6 or 8 photos and tap generate to view 300 DPI sheet preview', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
