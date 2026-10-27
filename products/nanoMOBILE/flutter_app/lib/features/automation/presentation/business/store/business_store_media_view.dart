import 'dart:io';
import 'package:flutter/material.dart';
import 'parallax/business_store_parallax_card.dart';
import 'parallax/device_tilt_service.dart';
import 'parallax/product_depth_controller.dart';

part 'business_store_media_state.part.dart';
part 'business_store_media_image.part.dart';

/// Presenta el archivo real, sin viñetas ni etiquetas de resolución inventadas.
/// Mantiene el efecto de profundidad opcional y su API para los consumidores.
class BusinessStoreMediaView extends StatefulWidget {
  final String? mediaPath;
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final bool showVideoBadge;
  final bool enableParallax;
  final DeviceTiltService? tiltService;

  const BusinessStoreMediaView({
    super.key,
    required this.mediaPath,
    this.height,
    this.width,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.showVideoBadge = true,
    this.enableParallax = false,
    this.tiltService,
  });

  @override
  State<BusinessStoreMediaView> createState() => _BusinessStoreMediaViewState();
}
