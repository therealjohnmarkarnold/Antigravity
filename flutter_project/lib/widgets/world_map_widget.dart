import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xml/xml.dart';

class WorldMapWidget extends StatefulWidget {
  final String targetCode;

  const WorldMapWidget({super.key, required this.targetCode});

  @override
  State<WorldMapWidget> createState() => _WorldMapWidgetState();
}

class _WorldMapWidgetState extends State<WorldMapWidget> {
  Future<String>? _svgFuture;
  final TransformationController _transformationController = TransformationController();
  double _currentZoom = 1.0;
  final double _minZoom = 1.0;
  final double _maxZoom = 10.0;

  @override
  void initState() {
    super.initState();
    _svgFuture = _loadSvg();
    _transformationController.addListener(_onMapInteraction);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onMapInteraction);
    _transformationController.dispose();
    super.dispose();
  }

  void _onMapInteraction() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (scale != _currentZoom) {
      if (mounted) {
        setState(() {
          _currentZoom = scale.clamp(_minZoom, _maxZoom);
        });
      }
    }
  }

  Future<String> _loadSvg() async {
    final String rawSvg = await rootBundle.loadString('assets/world-map.svg');
    final document = XmlDocument.parse(rawSvg);
    
    // Highlight target
    final String code = widget.targetCode.toLowerCase();
    
    // Find and style element
    XmlElement? targetElement;
    for (var element in document.findAllElements('path')) {
      if (element.getAttribute('id')?.toLowerCase() == code) {
        targetElement = element;
        break;
      }
    }
    if (targetElement == null) {
      for (var element in document.findAllElements('g')) {
        if (element.getAttribute('id')?.toLowerCase() == code) {
          targetElement = element;
          break;
        }
      }
    }

    if (targetElement != null) {
      targetElement.setAttribute('style', 'fill: #EF4444; stroke: white; stroke-width: 0.5;');
    } else {
        debugPrint("Could not find country code: $code");
    }

    // Return modified SVG string directly - no viewbox manipulation
    return document.toXmlString();
  }

  void _onSliderChanged(double value) {
    setState(() {
      _currentZoom = value;
    });
    
    // Zoom to center (simplified) or maintain current center
    // For now, simple scaling from identity matrix
    final Matrix4 newMatrix = Matrix4.diagonal3Values(value, value, 1.0);
    _transformationController.value = newMatrix;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _svgFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          children: [
            // Map
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: _minZoom,
              maxScale: _maxZoom,
              panEnabled: true,
              scaleEnabled: true,
              child: SvgPicture.string(
                snapshot.data!,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                placeholderBuilder: (_) => const Center(child: CircularProgressIndicator()),
              ),
            ),
            
            // Zoom Slider
            Positioned(
              right: 8,
              top: 20,
              bottom: 20,
              child: Container(
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                       color: Colors.black.withValues(alpha: 0.1),
                       blurRadius: 4,
                    )
                  ]
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, size: 20, color: Colors.black54),
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                          ),
                          child: Slider(
                            value: _currentZoom,
                            min: _minZoom,
                            max: _maxZoom,
                            activeColor: Colors.blueAccent,
                            inactiveColor: Colors.grey[300],
                            onChanged: _onSliderChanged,
                          ),
                        ),
                      ),
                    ),
                    const Icon(Icons.remove, size: 20, color: Colors.black54),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
