import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Reusable cached network image widget with built-in placeholder and error handling
/// 
/// Features:
/// - Automatic disk & memory caching
/// - Placeholder while loading
/// - Error widget on failure
/// - Configurable size and fit
class CachedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // Handle null or empty URL
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildErrorWidget();
    }

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? _buildPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _buildErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 100),
      // Cache settings - optimize for list view performance
      // Limit memory cache to actual display size (not full resolution)
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    if (backgroundColor != null) {
      image = Container(
        color: backgroundColor,
        child: image,
      );
    }

    return image;
  }

  Widget _buildPlaceholder() {
    // Lightweight placeholder - no spinner to reduce UI work
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Icon(
        Icons.image_outlined,
        color: Colors.grey[400],
        size: (width != null && height != null) 
            ? (width! < height! ? width! : height!) * 0.3 
            : 24,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[100],
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey[400],
        size: (width != null && height != null) 
            ? (width! < height! ? width! : height!) * 0.4 
            : 32,
      ),
    );
  }
}

/// Circular cached image (for avatars/profile pictures)
class CachedCircleAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? backgroundColor;

  const CachedCircleAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 24,
    this.placeholder,
    this.errorWidget,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey[200],
        child: errorWidget ?? Icon(
          Icons.person,
          size: radius,
          color: Colors.grey[400],
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
        backgroundColor: backgroundColor,
      ),
      placeholder: (context, url) => CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[200],
        child: placeholder ?? SizedBox(
          width: radius,
          height: radius,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
          ),
        ),
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey[200],
        child: errorWidget ?? Icon(
          Icons.person,
          size: radius,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}

/// Product image with default product icon fallback
class CachedProductImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const CachedProductImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return CachedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      errorWidget: Container(
        width: width,
        height: height,
        color: Colors.brown[50],
        child: Icon(
          Icons.inventory_2_outlined,
          color: Colors.brown[300],
          size: (width != null && height != null) 
              ? (width! < height! ? width! : height!) * 0.4 
              : 32,
        ),
      ),
    );
  }
}

/// Receipt/Document image with document icon fallback
class CachedDocumentImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const CachedDocumentImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return CachedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      errorWidget: Container(
        width: width,
        height: height,
        color: Colors.blue[50],
        child: Icon(
          Icons.description_outlined,
          color: Colors.blue[300],
          size: (width != null && height != null) 
              ? (width! < height! ? width! : height!) * 0.4 
              : 32,
        ),
      ),
    );
  }
}

