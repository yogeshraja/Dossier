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

  Uint8List _generateSampleCardImage(String title, Color bgColor) {
    final canvas = img.Image(width: 800, height: 500);
    final r = (bgColor.r * 255.0).round().clamp(0, 255);
    final g = (bgColor.g * 255.0).round().clamp(0, 255);
    final b = (bgColor.b * 255.0).round().clamp(0, 255);
    img.fill(canvas, color: img.ColorRgba8(r, g, b, 255));
    img.drawRect(canvas, x1: 20, y1: 20, x2: 780, y2: 480, color: img.ColorRgba8(255, 255, 255, 255));
    img.drawString(canvas, title, font: img.arial24, x: 50, y: 50, color: img.ColorRgba8(255, 255, 255, 255));
    return Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
  }

  Uint8List _generateSamplePortrait() {
    final canvas = img.Image(width: 600, height: 800);
    img.fill(canvas, color: img.ColorRgba8(59, 130, 246, 255));
    img.fillCircle(canvas, x: 300, y: 350, radius: 180, color: img.ColorRgba8(245, 158, 11, 255));
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header & Studio Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 750;

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.burst_mode_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Text('Media Prep Studio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Colors.grey,
                        tabs: const [
                          Tab(text: 'ID Stitcher'),
                          Tab(text: 'Compressor'),
                          Tab(text: 'Passport Grid'),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.burst_mode_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Media Prep Studio', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('Pure-Dart Background Isolates (Zero C++ Dependencies)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 440,
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Colors.grey,
                        tabs: const [
                          Tab(icon: Icon(Icons.style_rounded, size: 16), text: 'ID Stitcher'),
                          Tab(icon: Icon(Icons.compress_rounded, size: 16), text: 'Compressor'),
                          Tab(icon: Icon(Icons.grid_view_rounded, size: 16), text: 'Passport Grid'),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildResponsiveView(_buildIdStitcherControls(), _stitchedResult, 'Stitched A4 Page Output'),
                _buildResponsiveView(_buildCompressorControls(), _compressedResult, 'DCT Quantized Output'),
                _buildResponsiveView(_buildPassportStudioControls(), _passportGridResult, '4x6 Tiled Passport Sheet Output'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveView(Widget controls, Uint8List? resultBytes, String title) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        if (!isWide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                controls,
                const SizedBox(height: 20),
                Container(
                  height: 380,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Center(
                    child: resultBytes != null
                        ? Image.memory(resultBytes, fit: BoxFit.contain)
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.crop_original_rounded, size: 48, color: Colors.grey[500]),
                              const SizedBox(height: 8),
                              Text('No $title yet', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 320, child: controls),
              const SizedBox(width: 24),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Center(
                    child: resultBytes != null
                        ? Image.memory(resultBytes, fit: BoxFit.contain)
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.crop_original_rounded, size: 56, color: Colors.grey[500]),
                              const SizedBox(height: 12),
                              Text('No $title yet', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              const Text('Click the action button on the left to run background isolate computation',
                                  style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIdStitcherControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Front & Back ID Card Stitcher', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          'Merges front and back captures onto a standard A4 sheet with folding and cutting markers for rapid kiosk printing.',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _isStitching ? null : _runStitcherDemo,
          icon: _isStitching
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.auto_fix_high_rounded, size: 16),
          label: const Text('Stitch Front + Back ID'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.all(14)),
        ),
      ],
    );
  }

  Widget _buildCompressorControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Portal Target-Size Compressor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          'Enforces government portal upload bounds (< 200 KB or < 50 KB) via binary-search DCT quantization without visual distortion.',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _isCompressing ? null : () => _runCompressorDemo(200),
          icon: const Icon(Icons.compress_rounded, size: 16),
          label: const Text('Compress to < 200 KB'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.all(14)),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _isCompressing ? null : () => _runCompressorDemo(50),
          icon: const Icon(Icons.compress_rounded, size: 16),
          label: const Text('Compress to < 50 KB (Photo/Sign)'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), padding: const EdgeInsets.all(14)),
        ),
        if (_compressedResult != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Original: ${(_originalSize / 1024).toStringAsFixed(1)} KB', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 2),
                Text('Compressed: ${(_compressedSize / 1024).toStringAsFixed(1)} KB',
                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text('Reduced by: ${((1 - (_compressedSize / _originalSize)) * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPassportStudioControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('4x6 Passport Photo Studio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          'Auto-crops portrait shots to 35x45mm and tiles an aligned grid on a standard 4x6 inch photo print sheet with scissor guidelines.',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 6, label: Text('6 Photos (2x3)')),
            ButtonSegment(value: 8, label: Text('8 Photos (2x4)')),
          ],
          selected: {_photoCount},
          onSelectionChanged: (val) => setState(() => _photoCount = val.first),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _isGeneratingGrid ? null : _runPassportGridDemo,
          icon: _isGeneratingGrid
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.grid_on_rounded, size: 16),
          label: Text('Generate $_photoCount-Photo Sheet'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.all(14)),
        ),
      ],
    );
  }
}
