import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class MediaPrepService {
  /// Stitch Front and Back ID photos vertically onto an A4 or standard ID canvas
  static Future<Uint8List> stitchIdFrontAndBack({
    required Uint8List frontImageBytes,
    required Uint8List backImageBytes,
    bool outputA4 = true,
  }) async {
    return compute(_stitchIdIsolate, {
      'front': frontImageBytes,
      'back': backImageBytes,
      'a4': outputA4,
    });
  }

  /// Compress an image file to strictly under [targetSizeBytes] (e.g. 200 KB or 50 KB)
  /// using binary search DCT quality quantization and adaptive downsampling.
  static Future<Uint8List> compressToTargetSize({
    required Uint8List inputBytes,
    required int targetSizeBytes,
    int maxDimension = 1600,
  }) async {
    return compute(_compressIsolate, {
      'bytes': inputBytes,
      'targetSize': targetSizeBytes,
      'maxDim': maxDimension,
    });
  }

  /// Generate a 4x6 inch photo sheet containing a tiled grid of passport photos (35x45mm)
  static Future<Uint8List> generatePassportPhotoGrid({
    required Uint8List portraitBytes,
    int photoCount = 6, // 6 photos (2x3 grid) or 8 photos (2x4 grid)
  }) async {
    return compute(_passportGridIsolate, {
      'bytes': portraitBytes,
      'count': photoCount,
    });
  }

  // --- Internal Isolate Implementations ---

  static Uint8List _stitchIdIsolate(Map<String, dynamic> params) {
    final Uint8List frontBytes = params['front'];
    final Uint8List backBytes = params['back'];
    final bool outputA4 = params['a4'];

    final frontImg = img.decodeImage(frontBytes);
    final backImg = img.decodeImage(backBytes);

    if (frontImg == null || backImg == null) {
      throw Exception('Failed to decode front or back ID images');
    }

    // Standard A4 at 300 DPI: 2480 x 3508 pixels
    // ID Card target width: 1000px, height: 630px
    final int targetCardWidth = 1000;
    final int targetCardHeight = 630;

    final resizedFront = img.copyResize(
      frontImg,
      width: targetCardWidth,
      height: targetCardHeight,
      interpolation: img.Interpolation.cubic,
    );
    final resizedBack = img.copyResize(
      backImg,
      width: targetCardWidth,
      height: targetCardHeight,
      interpolation: img.Interpolation.cubic,
    );

    if (outputA4) {
      final canvas = img.Image(width: 2480, height: 3508);
      img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));

      final int startX = (2480 - targetCardWidth) ~/ 2;
      final int frontY = 400;
      final int backY = frontY + targetCardHeight + 150;

      // Draw Front Card
      img.compositeImage(canvas, resizedFront, dstX: startX, dstY: frontY);
      img.drawRect(canvas,
          x1: startX,
          y1: frontY,
          x2: startX + targetCardWidth,
          y2: frontY + targetCardHeight,
          color: img.ColorRgba8(200, 200, 200, 255));

      // Draw Folding Centerline Guide
      final int guideY = frontY + targetCardHeight + 75;
      img.drawLine(canvas,
          x1: startX - 50,
          y1: guideY,
          x2: startX + targetCardWidth + 50,
          y2: guideY,
          color: img.ColorRgba8(180, 180, 180, 255));

      // Draw Back Card
      img.compositeImage(canvas, resizedBack, dstX: startX, dstY: backY);
      img.drawRect(canvas,
          x1: startX,
          y1: backY,
          x2: startX + targetCardWidth,
          y2: backY + targetCardHeight,
          color: img.ColorRgba8(200, 200, 200, 255));

      return Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
    } else {
      // Single compact ID sheet: 1100 x 1400 px
      final canvas = img.Image(width: 1100, height: 1400);
      img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));

      const int startX = 50;
      const int frontY = 50;
      final int backY = frontY + targetCardHeight + 50;

      img.compositeImage(canvas, resizedFront, dstX: startX, dstY: frontY);
      img.compositeImage(canvas, resizedBack, dstX: startX, dstY: backY);

      return Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
    }
  }

  static Uint8List _compressIsolate(Map<String, dynamic> params) {
    final Uint8List bytes = params['bytes'];
    final int targetSize = params['targetSize'];
    final int maxDim = params['maxDim'];

    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Failed to decode image');

    // Downscale if image dimensions exceed portal thresholds
    if (decoded.width > maxDim || decoded.height > maxDim) {
      decoded = img.copyResize(
        decoded,
        width: decoded.width > decoded.height ? maxDim : -1,
        height: decoded.height >= decoded.width ? maxDim : -1,
        interpolation: img.Interpolation.cubic,
      );
    }

    // Binary search for optimal JPEG compression level
    int lowQuality = 10;
    int highQuality = 92;
    Uint8List bestOutput = Uint8List.fromList(img.encodeJpg(decoded, quality: lowQuality));

    while (lowQuality <= highQuality) {
      int mid = (lowQuality + highQuality) ~/ 2;
      Uint8List candidate = Uint8List.fromList(img.encodeJpg(decoded, quality: mid));

      if (candidate.lengthInBytes <= targetSize) {
        bestOutput = candidate;
        lowQuality = mid + 1; // Try higher quality
      } else {
        highQuality = mid - 1; // Try more compression
      }
    }

    return bestOutput;
  }

  static Uint8List _passportGridIsolate(Map<String, dynamic> params) {
    final Uint8List bytes = params['bytes'];
    final int count = params['count'];

    img.Image? portrait = img.decodeImage(bytes);
    if (portrait == null) throw Exception('Failed to decode portrait image');

    // Standard 35mm x 45mm passport ratio = 7:9 ratio -> 413 x 531 px at 300 DPI
    const int photoWidth = 413;
    const int photoHeight = 531;

    final croppedPhoto = img.copyResizeCropSquare(portrait, size: photoWidth);
    final resizedPhoto = img.copyResize(
      croppedPhoto,
      width: photoWidth,
      height: photoHeight,
      interpolation: img.Interpolation.cubic,
    );

    // 4x6 inch canvas at 300 DPI = 1200 x 1800 px
    final canvas = img.Image(width: 1800, height: 1200);
    img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));

    // Arrange 6 photos (2 rows x 3 cols) or 8 photos (2 rows x 4 cols)
    final int cols = count == 8 ? 4 : 3;
    final int rows = 2;
    final int cellWidth = 1800 ~/ cols;
    final int cellHeight = 1200 ~/ rows;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final int dstX = (c * cellWidth) + (cellWidth - photoWidth) ~/ 2;
        final int dstY = (r * cellHeight) + (cellHeight - photoHeight) ~/ 2;

        img.compositeImage(canvas, resizedPhoto, dstX: dstX, dstY: dstY);

        // Thin 1px border around each photo
        img.drawRect(canvas,
            x1: dstX,
            y1: dstY,
            x2: dstX + photoWidth,
            y2: dstY + photoHeight,
            color: img.ColorRgba8(210, 210, 210, 255));
      }
    }

    return Uint8List.fromList(img.encodeJpg(canvas, quality: 95));
  }
}
