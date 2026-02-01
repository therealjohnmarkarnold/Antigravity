import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:xml/xml.dart';

class WorldMapWidget extends StatefulWidget {
  final String targetCode;

  const WorldMapWidget({super.key, required this.targetCode});

  @override
  State<WorldMapWidget> createState() => _WorldMapWidgetState();
}

class _WorldMapWidgetState extends State<WorldMapWidget> {
  Future<String>? _svgFuture; // Returns SVG string
  final TransformationController _transformationController = TransformationController();
  
  // State for Pinned Zoom
  Rect _targetBounds = Rect.zero;
  Offset _viewportCenter = Offset.zero;
  
  double _currentZoom = 2.5; // Initial auto-zoom
  final double _minZoom = 0.5;
  final double _maxZoom = 20.0;

  @override
  void initState() {
    super.initState();
    _svgFuture = _loadAndProcessSvg();
    _transformationController.addListener(_onMapInteraction);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onMapInteraction);
    _transformationController.dispose();
    super.dispose();
  }

  // Handle updates from parent (new country selected)
  @override
  void didUpdateWidget(WorldMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetCode != widget.targetCode) {
       _currentZoom = 2.5; // Reset zoom for new question
       _svgFuture = _loadAndProcessSvg();
    }
  }

  Future<String> _loadAndProcessSvg() async {
    final String rawSvg = await rootBundle.loadString('assets/world-map.svg');
    final document = XmlDocument.parse(rawSvg);
    final String code = widget.targetCode.toLowerCase();
    
    XmlElement? targetElement;
    
    // 1. Find Element
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

    // 2. Highlight & Calculate Bounds
    Rect bounds = Rect.zero;
    if (targetElement != null) {
      targetElement.setAttribute('style', 'fill: #EF4444; stroke: white; stroke-width: 0.5;');
      
      String? dPath;
      if (targetElement.name.local == 'path') {
        dPath = targetElement.getAttribute('d');
      } else {
        final firstPath = targetElement.findElements('path').firstOrNull;
        dPath = firstPath?.getAttribute('d');
      }
      
      if (dPath != null) {
         try {
           final Path path = parseSvgPathData(dPath);
           bounds = path.getBounds();
         } catch (e) {
           debugPrint("Error parsing path bounds: $e");
         }
      }
    } else {
       debugPrint("Could not find country code: $code");
    }

    _targetBounds = bounds;
    
    // If we have bounds and viewport is ready, apply initial zoom
    if (_targetBounds != Rect.zero && _viewportCenter != Offset.zero) {
        // Enqueue update to run after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateMatrix();
        });
    }

    return document.toXmlString();
  }

  void _onMapInteraction() {
     // Optional: If user manually pans, we could update _currentZoom or allow "free mode".
     // For now, let's keep _currentZoom in sync with manual scale gestures
     final scale = _transformationController.value.getMaxScaleOnAxis();
      if (scale != _currentZoom) {
         // Debounce or check mount
         if (mounted) {
           setState(() {
             _currentZoom = scale.clamp(_minZoom, _maxZoom);
           });
         }
      }
  }
  
  void _onSliderChanged(double value) {
    setState(() {
      _currentZoom = value;
    });
    _updateMatrix();
  }
  
  // The Core Logic: Pin Zoom to Target Center
  void _updateMatrix() {
      if (_targetBounds == Rect.zero) return;
      
      final Offset targetCenter = _targetBounds.center;
      
      // M = Translate(ViewportCenter) * Scale(zoom) * Translate(-TargetCenter)
      final Matrix4 matrix = Matrix4.translationValues(_viewportCenter.dx, _viewportCenter.dy, 0)
        ..multiply(Matrix4.diagonal3Values(_currentZoom, _currentZoom, 1.0))
        ..multiply(Matrix4.translationValues(-targetCenter.dx, -targetCenter.dy, 0));

      _transformationController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Update viewport center
        _viewportCenter = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        
        return FutureBuilder<String>(
          future: _svgFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: _minZoom,
                  maxScale: _maxZoom,
                  panEnabled: true,
                  scaleEnabled: true,
                  constrained: false, // Allow map to be larger than screen
                  // We need to ensure the SVG is large enough to be zoomed. 
                  // SvgPicture.string usually fits to parent. 
                  // Let's force a large canvas size or fit=none if we want absolute coords.
                  // BUT: The path data is in specific coordinate space (approx 1000x500 for world map).
                  // If we use fit: BoxFit.none, it draws at 1:1 scale of the SVG coordinates.
                  // Then our matrix calculations work directly on those coordinates.
                  child: SvgPicture.string(
                    snapshot.data!,
                    fit: BoxFit.none, 
                    width: 1010, // Approx size of the loaded world map SVG
                    height: 666,
                    placeholderBuilder: (_) => const Center(child: CircularProgressIndicator()),
                  ),
                ),
                
                // Slider Overlay
                Positioned(
                  right: 8,
                  top: 20,
                  bottom: 20,
                  child: Container(
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                           color: Colors.black.withValues(alpha: 0.15),
                           blurRadius: 6,
                        )
                      ]
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         const Padding(
                           padding: EdgeInsets.only(top: 8.0),
                           child: Icon(Icons.zoom_in, size: 24, color: Colors.blueAccent),
                         ),
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 6,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
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
                         const Padding(
                           padding: EdgeInsets.only(bottom: 8.0),
                           child: Icon(Icons.zoom_out, size: 24, color: Colors.blueAccent),
                         ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
