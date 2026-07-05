import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'rice_ball_icon.dart';

class RestaurantImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Widget Function()? fallback;
  final ValueChanged<bool>? onFallbackChanged;

  const RestaurantImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.fallback,
    this.onFallbackChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fb = fallback?.call() ??
        const RiceBallIcon(size: null);

    if (url.isEmpty) {
      onFallbackChanged?.call(true);
      return fb;
    }

    if (url.startsWith('data:image/')) {
      try {
        final comma = url.indexOf(',');
        final bytes = base64Decode(url.substring(comma + 1));
        onFallbackChanged?.call(false);
        return Image.memory(bytes, fit: fit);
      } catch (_) {
        onFallbackChanged?.call(true);
        return fb;
      }
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      imageBuilder: (context, imageProvider) {
        onFallbackChanged?.call(false);
        return Image(image: imageProvider, fit: fit);
      },
      errorWidget: (_, __, ___) {
        onFallbackChanged?.call(true);
        return fb;
      },
    );
  }
}
