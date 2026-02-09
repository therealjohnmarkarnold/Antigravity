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
       // Reset zoom will be handled by _updateMatrix calculating a new auto-zoom
       _transformationController.value = Matrix4.identity(); 
       _svgFuture = _loadAndProcessSvg();
    }
  }

  Future<String> _loadAndProcessSvg() async {
    final String rawSvg = await rootBundle.loadString('assets/world-map.svg');
    final document = XmlDocument.parse(rawSvg);
    final String code = widget.targetCode.toLowerCase();
    
    XmlElement? targetElement;
    
    // 1. Find Element
    final String resolvedCode = _resolveCode(code);
    
    for (var element in document.findAllElements('path')) {
      if (element.getAttribute('id')?.toLowerCase() == resolvedCode) {
        targetElement = element;
        break;
      }
    }
    if (targetElement == null) {
      for (var element in document.findAllElements('g')) {
        if (element.getAttribute('id')?.toLowerCase() == resolvedCode) {
          targetElement = element;
          break;
        }
      }
    }

    // 2. Highlight & Calculate Bounds
    Rect bounds = Rect.zero;
    if (targetElement != null) {
      const String highlightStyle = 'fill: #EF4444; stroke: white; stroke-width: 0.5;';
      targetElement.setAttribute('style', highlightStyle);
      
      // Recursive style application for groups to ensure all parts highlight
      if (targetElement.name.local == 'g') {
         for (var child in targetElement.findAllElements('path')) {
            child.setAttribute('style', highlightStyle);
         }
      }
      
      List<String> paths = [];
      if (targetElement.name.local == 'path') {
        final d = targetElement.getAttribute('d');
        if (d != null) paths.add(d);
      } else {
        for (var child in targetElement.findAllElements('path')) {
           final d = child.getAttribute('d');
           if (d != null) paths.add(d);
        }
      }
      
      if (paths.isEmpty) {
         debugPrint("No paths found for country code: $code (resolved: $resolvedCode)");
      }

      double maxArea = -1.0;
      
      for (var d in paths) {
         try {
           final Path path = parseSvgPathData(d);
           final Rect pathBounds = path.getBounds();
           
           final double area = pathBounds.width * pathBounds.height;
           if (area > maxArea) {
             maxArea = area;
             bounds = pathBounds;
           }
         } catch (e) {
           debugPrint("Error parsing path data: $e");
         }
      }
    } else {
    } else {
       debugPrint("Could not find country code: $code (resolved: $resolvedCode). Check SVG IDs.");
    }

    _targetBounds = bounds;
    
    return document.toXmlString();
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
  
  void _onSliderChanged(double value) {
    setState(() {
      _currentZoom = value;
    });
    _updateMatrix(manualOverride: true);
  }
  
  // Handle aliases for countries not in the SVG or needing remapping
  String _resolveCode(String code) {
    const Map<String, String> aliases = {
      'xk': 'rs', // Kosovo -> Serbia (in this map data)
      'ps': 'il', // Palestine -> Israel (in this map data)
      'va': 'it', // Vatican City -> Italy (in this map data)
      'ax': 'fi', // Aland Islands -> Finland
    };
    return aliases[code] ?? code;
  }
  
  // The Core Logic: Pin Zoom to Target Center with Dynamic Scale
  void _updateMatrix({bool manualOverride = false}) {
      if (_targetBounds == Rect.zero) return;
      
      // ViewBox offset from SVG
      const double offsetX = 30.767;
      const double offsetY = 241.591;
      
      final Offset rawCenter = _targetBounds.center;
      final Offset correctedCenter = Offset(rawCenter.dx - offsetX, rawCenter.dy - offsetY);
      
      // Calculate Dynamic Auto-Zoom if this is an initial update (not slider interaction)
      if (!manualOverride && _viewportCenter != Offset.zero) {
        // Goal: Target bounds should fill ~75% of the shortest viewport dimension
        // Bounds dimensions are in SVG space (784x458 base)
        
        final double targetW = _targetBounds.width;
        final double targetH = _targetBounds.height;
        
        if (targetW > 0 && targetH > 0) {
             // Screen dimensions (viewport)
             final double screenW = _viewportCenter.dx * 2;
             final double screenH = _viewportCenter.dy * 2;
             
             // Scale factors to fit width/height
             // Target ~25% of view area -> 0.5 of linear dimension
             final double scaleW = (screenW * 0.50) / targetW;
             final double scaleH = (screenH * 0.50) / targetH;
             
             // Use the smaller scale to ensure it fits (contain)
             double optimalZoom = (scaleW < scaleH) ? scaleW : scaleH;
             
             // Apply and clamp
             _currentZoom = optimalZoom.clamp(_minZoom, _maxZoom);
             
             // Notify the slider if we need to update state? 
             // Since we modify _currentZoom directly here, setState isn't strictly needed for the transform,
             // but if the Slider widget depends on it, we might want to schedule a rebuild.
             // However, strictly inside this method which is called post-frame, we should avoid setState loop.
             // But let's assume _currentZoom is read by the slider build.
        }
      }

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
        _viewportCenter = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        
        if (_targetBounds != Rect.zero) {
           if (_transformationController.value == Matrix4.identity()) {
               WidgetsBinding.instance.addPostFrameCallback((_) => _updateMatrix(manualOverride: false));
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
                  constrained: false, 
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
