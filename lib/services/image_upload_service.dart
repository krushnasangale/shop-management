import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageUploadService {
  static const int maxImageSize =
      800; // Reduced from 1024 for better compression
  static const int maxFileSizeKB = 300; // Maximum file size in KB (300KB limit)
  static const int jpegQuality =
      85; // Starting JPEG quality (will reduce if needed)

  /// Uploads an image to Firebase Storage with compression
  /// [userId] - The user ID for organizing files in storage
  /// [productId] - The product ID for the file name
  /// [image] - The image file to upload
  /// [deleteOldImage] - Whether to delete the existing image before uploading
  /// [onProgress] - Optional callback for upload progress (0.0 to 1.0)
  static Future<String?> uploadProductImage({
    required String userId,
    required String productId,
    required File? image,
    bool deleteOldImage = false,
    Function(double progress)? onProgress,
  }) async {
    if (image == null) return null;

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('product-images')
          .child(userId)
          .child('$productId.jpg');

      // Delete old image if requested
      if (deleteOldImage) {
        try {
          await storageRef.delete();
        } catch (e) {
          // Ignore if the file doesn't exist
        }
      }

      // Report initial progress
      onProgress?.call(0.0);

      // Compress the image in background isolate (20% of total progress for compression)
      final compressedFile = await compute(_compressImageIsolate, {
        'imagePath': image.path,
        'productId': productId,
      });
      onProgress?.call(0.2);

      // Upload the compressed image with progress tracking
      final uploadTask = storageRef.putFile(compressedFile);

      // Listen to upload progress if callback provided (80% of total progress)
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            final uploadProgress =
                snapshot.bytesTransferred / snapshot.totalBytes;
            // Map upload progress from 0.2 to 1.0
            final totalProgress = 0.2 + (uploadProgress * 0.8);
            onProgress(totalProgress.clamp(0.2, 1.0));
          }
        });
      }

      await uploadTask;
      final downloadUrl = await storageRef.getDownloadURL();

      // Clean up temporary file
      await compressedFile.delete();

      return downloadUrl;
    } catch (e) {
      // Error uploading image
      return null;
    }
  }

  /// Isolate function for image compression (runs in background)
  static Future<File> _compressImageIsolate(Map<String, dynamic> params) async {
    final String imagePath = params['imagePath'];
    final String productId = params['productId'];
    final imageFile = File(imagePath);

    try {
      // Read the image file
      final imageBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        return imageFile;
      }

      // Resize the image to reduce size
      img.Image resizedImage;
      if (originalImage.width > originalImage.height) {
        if (originalImage.width > maxImageSize) {
          resizedImage = img.copyResize(originalImage, width: maxImageSize);
        } else {
          resizedImage = originalImage;
        }
      } else {
        if (originalImage.height > maxImageSize) {
          resizedImage = img.copyResize(originalImage, height: maxImageSize);
        } else {
          resizedImage = originalImage;
        }
      }

      // Create a temporary file for the compressed image
      final tempDir = await Directory.systemTemp.createTemp();
      final compressedFile = File('${tempDir.path}/compressed_$productId.jpg');

      // Estimate optimal quality based on image dimensions to reduce iterations
      final pixels = resizedImage.width * resizedImage.height;
      int quality = _estimateQuality(pixels);
      const int minQuality = 30;

      // Try compression with estimated quality first
      var compressedBytes = img.encodeJpg(resizedImage, quality: quality);
      await compressedFile.writeAsBytes(compressedBytes);
      var fileSizeKB = compressedBytes.length / 1024;

      // If size is too large, do binary search for optimal quality (faster than linear)
      if (fileSizeKB > maxFileSizeKB) {
        int lowQuality = minQuality;
        int highQuality = quality;

        while (lowQuality <= highQuality && fileSizeKB > maxFileSizeKB) {
          quality = (lowQuality + highQuality) ~/ 2;
          compressedBytes = img.encodeJpg(resizedImage, quality: quality);
          fileSizeKB = compressedBytes.length / 1024;

          if (fileSizeKB > maxFileSizeKB) {
            highQuality = quality - 1;
          } else {
            lowQuality = quality + 1;
          }
        }

        await compressedFile.writeAsBytes(compressedBytes);
      }

      return compressedFile;
    } catch (e) {
      return imageFile;
    }
  }

  /// Estimate initial quality based on image size
  static int _estimateQuality(int pixels) {
    if (pixels < 100000) return 85; // Very small images
    if (pixels < 300000) return 75; // Small images
    if (pixels < 500000) return 65; // Medium images
    return 55; // Large images
  }

  /// Deletes an image from Firebase Storage by URL
  static Future<void> deleteImageByUrl(String imageUrl) async {
    try {
      // Extract the path from the URL
      // Firebase Storage URLs have format: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{path}?alt=media&token={token}
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      // Find the path after '/o/' and before the query parameters
      final oIndex = pathSegments.indexOf('o');
      if (oIndex != -1 && oIndex + 1 < pathSegments.length) {
        final encodedPath = pathSegments[oIndex + 1];
        // URL decode the path
        final imagePath = Uri.decodeComponent(encodedPath);

        final storageRef = FirebaseStorage.instance.ref().child(imagePath);
        await storageRef.delete();
      }
    } catch (e) {
      // Silently fail if deletion fails
    }
  }
}
