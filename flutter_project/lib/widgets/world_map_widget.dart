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
       _transformationController.value = Matrix4.identity(); // Reset view to trigger auto-zoom
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
      
      List<String> paths = [];
      if (targetElement.name.local == 'path') {
        final d = targetElement.getAttribute('d');
        if (d != null) paths.add(d);
      } else {
        // It's a group, gather all child paths
        // Use recursive find if needed, closely matching structure
        for (var child in targetElement.findAllElements('path')) {
           final d = child.getAttribute('d');
           if (d != null) paths.add(d);
        }
      }
      
      if (paths.isEmpty) {
         debugPrint("No paths found for country code: $code");
      }

      for (var d in paths) {
         try {
           final Path path = parseSvgPathData(d);
           final Rect pathBounds = path.getBounds();
           if (bounds == Rect.zero) {
             bounds = pathBounds;
           } else {
             bounds = bounds.expandToInclude(pathBounds);
           }
         } catch (e) {
           debugPrint("Error parsing path data: $e");
         }
      }
    } else {
       debugPrint("Could not find country code: $code");
    }

    _targetBounds = bounds;
    
    // Bounds calculated. _updateMatrix will be triggered by LayoutBuilder if needed,
    // or next time we slide.
    
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
      
      // The SVG has a viewBox offset. We must subtract this to get the visual coordinate
      // relative to the top-left of the SvgPicture (0,0).
      // ViewBox: x=30.767, y=241.591
      const double offsetX = 30.767;
      const double offsetY = 241.591;
      
      final Offset rawCenter = _targetBounds.center;
      final Offset correctedCenter = Offset(rawCenter.dx - offsetX, rawCenter.dy - offsetY);
      
      // M = Translate(ViewportCenter) * Scale(zoom) * Translate(-CorrectedCenter)
      final Matrix4 matrix = Matrix4.translationValues(_viewportCenter.dx, _viewportCenter.dy, 0)
        ..multiply(Matrix4.diagonal3Values(_currentZoom, _currentZoom, 1.0))
        ..multiply(Matrix4.translationValues(-correctedCenter.dx, -correctedCenter.dy, 0));

      _transformationController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Update viewport center
        _viewportCenter = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        
        // If we have bounds but haven't zoomed yet (or just need to refresh center), check logic
        if (_targetBounds != Rect.zero) {
           if (_transformationController.value == Matrix4.identity()) {
               WidgetsBinding.instance.addPostFrameCallback((_) => _updateMatrix());
           }
        }
        
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
                  // Use EXACT dimensions from the SVG to ensure 1:1 mapping with path coordinates
                  child: SvgPicture.string(
                    snapshot.data!,
                    fit: BoxFit.none, 
                    width: 784.077, 
                    height: 458.627,
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
