import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dossier/data/local/app_database.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/domain/services/media_prep_service.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';
import 'package:dossier/presentation/common_widgets/dossier_resizable_split_view.dart';

class MediaPrepStudioScreen extends ConsumerStatefulWidget {
  const MediaPrepStudioScreen({super.key});

  @override
  ConsumerState<MediaPrepStudioScreen> createState() => _MediaPrepStudioScreenState();
}

class _MediaPrepStudioScreenState extends ConsumerState<MediaPrepStudioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Stitcher State
  PlatformFile? _frontCardFile;
  Uint8List? _frontCardBytes;
  PlatformFile? _backCardFile;
  Uint8List? _backCardBytes;
  Uint8List? _stitchedResult;
  bool _isStitching = false;

  // Compressor State
  PlatformFile? _compressSourceFile;
  Uint8List? _compressSourceBytes;
  Uint8List? _compressedResult;
  int _originalSize = 0;
  int _compressedSize = 0;
  int _targetKb = 100;
  bool _isCompressing = false;

  // Passport Studio State
  PlatformFile? _portraitSourceFile;
  Uint8List? _portraitSourceBytes;
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

  // --- Real File Pickers ---

  Future<void> _pickFrontCard() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
        if (bytes != null) {
          setState(() {
            _frontCardFile = file;
            _frontCardBytes = bytes;
            _stitchedResult = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting front card: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _pickBackCard() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
        if (bytes != null) {
          setState(() {
            _backCardFile = file;
            _backCardBytes = bytes;
            _stitchedResult = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting back card: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _runStitcher() async {
    if (_frontCardBytes == null || _backCardBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both Front and Back card images.')),
      );
      return;
    }

    setState(() => _isStitching = true);
    try {
      final result = await MediaPrepService.stitchIdFrontAndBack(
        frontImageBytes: _frontCardBytes!,
        backImageBytes: _backCardBytes!,
        outputA4: true,
      );

      setState(() => _stitchedResult = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stitching ID cards: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isStitching = false);
    }
  }

  Future<void> _pickCompressSource() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
        if (bytes != null) {
          setState(() {
            _compressSourceFile = file;
            _compressSourceBytes = bytes;
            _originalSize = bytes.lengthInBytes;
            _compressedResult = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _runCompressor(int targetKb) async {
    if (_compressSourceBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick an image to compress first.')),
      );
      return;
    }

    setState(() {
      _isCompressing = true;
      _targetKb = targetKb;
    });

    try {
      final result = await MediaPrepService.compressToTargetSize(
        inputBytes: _compressSourceBytes!,
        targetSizeBytes: targetKb * 1024,
      );

      setState(() {
        _compressedResult = result;
        _compressedSize = result.lengthInBytes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error compressing image: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isCompressing = false);
    }
  }

  Future<void> _pickPortraitSource() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
        if (bytes != null) {
          setState(() {
            _portraitSourceFile = file;
            _portraitSourceBytes = bytes;
            _passportGridResult = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting portrait photo: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _runPassportGrid() async {
    if (_portraitSourceBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer portrait photo first.')),
      );
      return;
    }

    setState(() => _isGeneratingGrid = true);
    try {
      final result = await MediaPrepService.generatePassportPhotoGrid(
        portraitBytes: _portraitSourceBytes!,
        photoCount: _photoCount,
      );
      setState(() => _passportGridResult = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating passport grid: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingGrid = false);
    }
  }

  Future<void> _saveOutputBytes(Uint8List bytes, String defaultName) async {
    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Processed Document Image',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png'],
      );

      if (savePath != null) {
        await File(savePath).writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File saved successfully to: $savePath'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving file: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _attachToActiveCase(Uint8List bytes, String slotType, String defaultFilename) async {
    final activeCase = ref.read(activeCaseProvider);
    if (activeCase == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active case selected. Please select a customer case in the Dossiers tab first.')),
      );
      return;
    }

    try {
      final db = ref.read(databaseProvider);
      const uuid = Uuid();
      final tempDir = Directory.systemTemp;
      final fileId = uuid.v4().substring(0, 8);
      final filePath = '${tempDir.path}/dossier_${fileId}_$defaultFilename';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      await db.insertExhibit(
        ExhibitsCompanion.insert(
          id: uuid.v4(),
          caseId: activeCase.id,
          slotType: slotType,
          fileName: defaultFilename,
          mimeType: 'image/jpeg',
          fileSizeBytes: bytes.lengthInBytes,
          localPath: drift.Value(filePath),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully attached "$defaultFilename" to Case "${activeCase.title}"!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error attaching to case: $e'), backgroundColor: Colors.redAccent),
        );
      }
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
                              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.burst_mode_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Media Prep Studio',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 8),
                                DossierBadge(label: 'DOCUMENT TOOLS', variant: DossierBadgeVariant.info),
                              ],
                            ),
                          ),
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
                        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.burst_mode_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Media Prep Studio', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            DossierBadge(label: 'HIGH SPEED', variant: DossierBadgeVariant.info),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text('Fast ID Card Stitching, Compression & Passport Photo Tiling', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                _buildResponsiveView(
                  _buildIdStitcherControls(),
                  _stitchedResult,
                  'Stitched A4 Page Output',
                  'Aadhaar Front/Back',
                  'stitched_id_a4.jpg',
                  () => _stitchedResult != null ? _saveOutputBytes(_stitchedResult!, 'stitched_id_a4.jpg') : null,
                  () => _stitchedResult != null ? _attachToActiveCase(_stitchedResult!, 'Aadhaar Card', 'stitched_id_a4.jpg') : null,
                ),
                _buildResponsiveView(
                  _buildCompressorControls(),
                  _compressedResult,
                  'DCT Quantized Output',
                  'Compressed Document',
                  'compressed_${_targetKb}kb.jpg',
                  () => _compressedResult != null ? _saveOutputBytes(_compressedResult!, 'compressed_${_targetKb}kb.jpg') : null,
                  () => _compressedResult != null ? _attachToActiveCase(_compressedResult!, 'Compressed Document', 'compressed_${_targetKb}kb.jpg') : null,
                ),
                _buildResponsiveView(
                  _buildPassportStudioControls(),
                  _passportGridResult,
                  '4x6 Tiled Passport Sheet Output',
                  'Passport Photo Grid',
                  'passport_grid_${_photoCount}p.jpg',
                  () => _passportGridResult != null ? _saveOutputBytes(_passportGridResult!, 'passport_grid_${_photoCount}p.jpg') : null,
                  () => _passportGridResult != null ? _attachToActiveCase(_passportGridResult!, 'Passport Photo Grid', 'passport_grid_${_photoCount}p.jpg') : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveView(
    Widget controls,
    Uint8List? resultBytes,
    String title,
    String slotType,
    String filename,
    VoidCallback? onSave,
    VoidCallback? onAttach,
  ) {
    final activeCase = ref.watch(activeCaseProvider);

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
                DossierCard(
                  variant: DossierCardVariant.glass,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 340,
                        child: Center(
                          child: resultBytes != null
                              ? Image.memory(resultBytes, fit: BoxFit.contain)
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.crop_original_rounded, size: 48, color: Colors.grey[500]),
                                    const SizedBox(height: 8),
                                    Text('No $title yet', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    const Text('Select source images and click Process', style: TextStyle(color: Colors.grey, fontSize: 11.5)),
                                  ],
                                ),
                        ),
                      ),
                      if (resultBytes != null) ...[
                        const SizedBox(height: 12),
                        if (activeCase != null && onAttach != null) ...[
                          DossierButton(
                            text: 'Attach to Case #${activeCase.title}',
                            icon: Icons.attach_file_rounded,
                            variant: DossierButtonVariant.primary,
                            size: DossierButtonSize.md,
                            isFullWidth: true,
                            onPressed: onAttach,
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (onSave != null)
                          DossierButton(
                            text: 'Export File to Disk',
                            icon: Icons.save_alt_rounded,
                            variant: DossierButtonVariant.outline,
                            size: DossierButtonSize.md,
                            isFullWidth: true,
                            onPressed: onSave,
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: DossierResizableSplitView(
            direction: Axis.horizontal,
            responsiveBreakpoint: 800.0,
            panes: [
              ResizablePane(
                id: 'media_controls',
                initialSize: 380.0,
                minSize: 280.0,
                maxSize: 520.0,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 8),
                  child: controls,
                ),
              ),
              ResizablePane(
                id: 'media_preview',
                isFlexible: true,
                minSize: 320.0,
                child: DossierCard(
                  variant: DossierCardVariant.glass,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: resultBytes != null
                              ? InteractiveViewer(
                                  panEnabled: true,
                                  boundaryMargin: const EdgeInsets.all(20),
                                  minScale: 0.8,
                                  maxScale: 3.0,
                                  child: Image.memory(resultBytes, fit: BoxFit.contain),
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.crop_original_rounded, size: 56, color: Colors.grey[500]),
                                    const SizedBox(height: 12),
                                    Text('No $title yet', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    const Text('Select source images on the left and click Process',
                                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                        ),
                      ),
                      if (resultBytes != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (activeCase != null && onAttach != null) ...[
                              DossierButton(
                                text: 'Attach to Case #${activeCase.title}',
                                icon: Icons.attach_file_rounded,
                                variant: DossierButtonVariant.primary,
                                size: DossierButtonSize.md,
                                onPressed: onAttach,
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (onSave != null)
                              DossierButton(
                                text: 'Export File',
                                icon: Icons.save_alt_rounded,
                                variant: DossierButtonVariant.outline,
                                size: DossierButtonSize.md,
                                onPressed: onSave,
                              ),
                          ],
                        ),
                      ],
                    ],
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
        const SizedBox(height: 16),

        // Front Card Selector
        DossierCard(
          variant: DossierCardVariant.flat,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('1. ID Front Side', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (_frontCardFile != null)
                    const DossierBadge(label: 'SELECTED', variant: DossierBadgeVariant.success),
                ],
              ),
              const SizedBox(height: 8),
              if (_frontCardBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_frontCardBytes!, height: 80, width: double.infinity, fit: BoxFit.cover),
                ),
              const SizedBox(height: 8),
              DossierButton(
                text: _frontCardFile != null ? 'Change Front Image' : 'Pick Front ID Image',
                icon: Icons.image_search_rounded,
                variant: DossierButtonVariant.outline,
                size: DossierButtonSize.sm,
                isFullWidth: true,
                onPressed: _pickFrontCard,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Back Card Selector
        DossierCard(
          variant: DossierCardVariant.flat,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('2. ID Back Side', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (_backCardFile != null)
                    const DossierBadge(label: 'SELECTED', variant: DossierBadgeVariant.success),
                ],
              ),
              const SizedBox(height: 8),
              if (_backCardBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_backCardBytes!, height: 80, width: double.infinity, fit: BoxFit.cover),
                ),
              const SizedBox(height: 8),
              DossierButton(
                text: _backCardFile != null ? 'Change Back Image' : 'Pick Back ID Image',
                icon: Icons.image_search_rounded,
                variant: DossierButtonVariant.outline,
                size: DossierButtonSize.sm,
                isFullWidth: true,
                onPressed: _pickBackCard,
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        DossierButton(
          text: 'Stitch Front + Back to A4',
          icon: Icons.auto_fix_high_rounded,
          isLoading: _isStitching,
          variant: DossierButtonVariant.primary,
          size: DossierButtonSize.lg,
          isFullWidth: true,
          onPressed: (_frontCardBytes != null && _backCardBytes != null && !_isStitching) ? _runStitcher : null,
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
          'Reduces image file size to meet government portal upload limits (e.g. < 200 KB or < 50 KB) while maintaining sharp quality.',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        const SizedBox(height: 16),

        // Pick Image Area
        DossierCard(
          variant: DossierCardVariant.flat,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Source Document / Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (_compressSourceFile != null)
                    DossierBadge(
                      label: '${(_originalSize / 1024).toStringAsFixed(0)} KB',
                      variant: DossierBadgeVariant.primary,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_compressSourceBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_compressSourceBytes!, height: 90, width: double.infinity, fit: BoxFit.cover),
                ),
              const SizedBox(height: 8),
              DossierButton(
                text: _compressSourceFile != null ? 'Change Image (${_compressSourceFile!.name})' : 'Pick Image to Compress',
                icon: Icons.upload_file_rounded,
                variant: DossierButtonVariant.outline,
                size: DossierButtonSize.sm,
                isFullWidth: true,
                onPressed: _pickCompressSource,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        const Text('Target Output Size Bound:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('< 50 KB (Photo/Sign)'),
              selected: _targetKb == 50,
              onSelected: (val) {
                if (val && _compressSourceBytes != null) _runCompressor(50);
              },
            ),
            ChoiceChip(
              label: const Text('< 100 KB'),
              selected: _targetKb == 100,
              onSelected: (val) {
                if (val && _compressSourceBytes != null) _runCompressor(100);
              },
            ),
            ChoiceChip(
              label: const Text('< 200 KB (Govt Portals)'),
              selected: _targetKb == 200,
              onSelected: (val) {
                if (val && _compressSourceBytes != null) _runCompressor(200);
              },
            ),
            ChoiceChip(
              label: const Text('< 500 KB'),
              selected: _targetKb == 500,
              onSelected: (val) {
                if (val && _compressSourceBytes != null) _runCompressor(500);
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        DossierButton(
          text: 'Compress to < $_targetKb KB',
          icon: Icons.compress_rounded,
          isLoading: _isCompressing,
          variant: DossierButtonVariant.primary,
          size: DossierButtonSize.md,
          isFullWidth: true,
          onPressed: (_compressSourceBytes != null && !_isCompressing) ? () => _runCompressor(_targetKb) : null,
        ),

        if (_compressedResult != null) ...[
          const SizedBox(height: 16),
          DossierCard(
            variant: DossierCardVariant.glass,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Compression Ratio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '-${((1 - (_compressedSize / _originalSize)) * 100).toStringAsFixed(0)}% REDUCED',
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (_compressedSize / _originalSize).clamp(0.05, 1.0),
                  backgroundColor: Theme.of(context).dividerColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 6,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Original: ${(_originalSize / 1024).toStringAsFixed(1)} KB', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    Text('Result: ${(_compressedSize / 1024).toStringAsFixed(1)} KB',
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
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

        // Pick Portrait Area
        DossierCard(
          variant: DossierCardVariant.flat,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Customer Portrait Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (_portraitSourceFile != null)
                    const DossierBadge(label: 'READY', variant: DossierBadgeVariant.success),
                ],
              ),
              const SizedBox(height: 8),
              if (_portraitSourceBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_portraitSourceBytes!, height: 90, width: double.infinity, fit: BoxFit.cover),
                ),
              const SizedBox(height: 8),
              DossierButton(
                text: _portraitSourceFile != null ? 'Change Portrait (${_portraitSourceFile!.name})' : 'Pick Customer Portrait Photo',
                icon: Icons.person_search_rounded,
                variant: DossierButtonVariant.outline,
                size: DossierButtonSize.sm,
                isFullWidth: true,
                onPressed: _pickPortraitSource,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 6, label: Text('6 Photos (2x3)')),
            ButtonSegment(value: 8, label: Text('8 Photos (2x4)')),
            ButtonSegment(value: 12, label: Text('12 Photos (3x4)')),
          ],
          selected: {_photoCount},
          onSelectionChanged: (val) => setState(() => _photoCount = val.first),
        ),
        const SizedBox(height: 16),
        DossierButton(
          text: 'Generate $_photoCount-Photo Sheet',
          icon: Icons.grid_on_rounded,
          isLoading: _isGeneratingGrid,
          variant: DossierButtonVariant.primary,
          size: DossierButtonSize.lg,
          isFullWidth: true,
          onPressed: (_portraitSourceBytes != null && !_isGeneratingGrid) ? _runPassportGrid : null,
        ),
      ],
    );
  }
}
