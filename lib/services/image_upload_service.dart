import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
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

      // Compress the image (20% of total progress for compression)
      final compressedFile = await _compressImage(image, productId);
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

  /// Compresses an image file by resizing and reducing quality to meet file size limit
  static Future<File> _compressImage(File imageFile, String productId) async {
    try {
      // Read the image file
      final imageBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        // If decoding fails, return original file
        return imageFile;
      }

      // Resize the image to reduce size while maintaining quality
      img.Image resizedImage;

      if (originalImage.width > originalImage.height) {
        // Landscape
        if (originalImage.width > maxImageSize) {
          resizedImage = img.copyResize(originalImage, width: maxImageSize);
        } else {
          resizedImage = originalImage;
        }
      } else {
        // Portrait or square
        if (originalImage.height > maxImageSize) {
          resizedImage = img.copyResize(originalImage, height: maxImageSize);
        } else {
          resizedImage = originalImage;
        }
      }

      // Create a temporary file for the compressed image
      final tempDir = await Directory.systemTemp.createTemp();
      final compressedFile = File('${tempDir.path}/compressed_$productId.jpg');

      // Iteratively compress until file size is under limit
      int quality = jpegQuality;
      const int minQuality = 30; // Minimum acceptable quality
      const int qualityStep = 10; // Quality reduction step

      while (quality >= minQuality) {
        final compressedBytes = img.encodeJpg(resizedImage, quality: quality);
        await compressedFile.writeAsBytes(compressedBytes);

        // Check file size
        final fileSizeKB = await compressedFile.length() / 1024;
        if (fileSizeKB <= maxFileSizeKB) {
          // File size is acceptable
          return compressedFile;
        }

        // Reduce quality for next iteration
        quality -= qualityStep;
      }

      // If we couldn't achieve the target size, return the lowest quality version
      final compressedBytes = img.encodeJpg(resizedImage, quality: minQuality);
      await compressedFile.writeAsBytes(compressedBytes);
      return compressedFile;
    } catch (e) {
      // If compression fails, return original file
      return imageFile;
    }
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
