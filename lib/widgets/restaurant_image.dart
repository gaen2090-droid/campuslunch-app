import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RestaurantImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Widget Function()? fallback;

  const RestaurantImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final fb = fallback?.call() ??
        Container(
          color: const Color(0xFF2D2D2D),
          child: const Center(
            child: Icon(Icons.restaurant, size: 22, color: Color(0xFF1A1A1A)),
          ),
        );

    if (url.isEmpty) return fb;

    if (url.startsWith('data:image/')) {
      try {
        final comma = url.indexOf(',');
        final bytes = base64Decode(url.substring(comma + 1));
        return Image.memory(bytes, fit: fit);
      } catch (_) {
        return fb;
      }
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      errorWidget: (_, __, ___) => fb,
    );
  }
}
