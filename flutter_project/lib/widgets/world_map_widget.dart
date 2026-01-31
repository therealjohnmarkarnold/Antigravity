import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:xml/xml.dart'; // Upgrade to xml 6.x usage if needed

class WorldMapWidget extends StatefulWidget {
  final String targetCode;

  const WorldMapWidget({super.key, required this.targetCode});

  @override
  State<WorldMapWidget> createState() => _WorldMapWidgetState();
}

class _WorldMapWidgetState extends State<WorldMapWidget> {
  Future<MapData>? _mapDataFuture;

  @override
  void initState() {
    super.initState();
    _mapDataFuture = _processMap();
  }
  
  @override
  void didUpdateWidget(WorldMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetCode != widget.targetCode) {
      _mapDataFuture = _processMap();
    }
  }

  Future<MapData> _processMap() async {
    final String rawSvg = await rootBundle.loadString('assets/world-map.svg');
    final document = XmlDocument.parse(rawSvg);
    
    // Find target element
    final String code = widget.targetCode.toLowerCase();
    XmlElement? targetElement;
    
    // Search by ID 
    // Note: This matches the JS logic: lowercase check
    for (var element in document.findAllElements('path')) {
      final id = element.getAttribute('id')?.toLowerCase();
      if (id == code) {
        targetElement = element;
        break;
      }
    }
    
    // Also check 'g' tags if individual path not found (some maps group islands)
    if (targetElement == null) {
       for (var element in document.findAllElements('g')) {
          final id = element.getAttribute('id')?.toLowerCase();
          if (id == code) {
            targetElement = element;
            break;
          }
       }
    }

    Rect bounds = Rect.zero;
    
    if (targetElement != null) {
      // Highlight: Set fill color
      targetElement.setAttribute('style', 'fill: #EF4444; stroke: white; stroke-width: 0.5;');
      // Or set explicit attributes if style string parsing is complex for SvgPicture
      // Usually SvgPicture respects inline styles well.
      
      // Calculate Bounds
      // If it's a group, we might need to iterate children. For simplicity, let's look for 'd' in the element or first child path.
      String? dPath;
      if (targetElement.name.local == 'path') {
        dPath = targetElement.getAttribute('d');
      } else {
        // Find first path in group
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
    }

    if (bounds != Rect.zero) {
      // Calculate new ViewBox
      final double padding = 1.5; // 150%
      final double minSize = 250.0;
      
      double width = bounds.width * padding;
      double height = bounds.height * padding;
      
      if (width < minSize) width = minSize;
      if (height < minSize) height = minSize;
      
      final double cx = bounds.center.dx;
      final double cy = bounds.center.dy;
      
      final double x = cx - (width / 2);
      final double y = cy - (height / 2);
      
      // Update SVG viewBox
      final root = document.rootElement;
      root.setAttribute('viewBox', '$x $y $width $height');
    }

    return MapData(
      svgContent: document.toXmlString(),
      targetBounds: bounds,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MapData>(
      future: _mapDataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        return SvgPicture.string(
          snapshot.data!.svgContent,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class MapData {
  final String svgContent;
  final Rect targetBounds;
  MapData({required this.svgContent, required this.targetBounds});
}

