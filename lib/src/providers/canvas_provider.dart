import 'package:flutter/material.dart';
import '../core/utils/canvas_utils.dart';
import '../core/enums/cable_type.dart';

/// The current interaction mode on the canvas.
enum CanvasMode {
  /// Default: tap to select, drag to move devices.
  select,

  /// Tap two devices to create a connection between them.
  connect,

  /// Tap a device or connection to delete it.
  delete,
}

/// Manages canvas viewport state: zoom, pan, grid, and interaction mode.
class CanvasProvider extends ChangeNotifier {
  final TransformationController transformController = TransformationController(
    Matrix4.identity()
      // ignore: deprecated_member_use
      ..translate(-5000.0 * 0.75 + 500.0, -5000.0 * 0.75 + 1000.0)
      // ignore: deprecated_member_use
      ..scale(0.75), 
  );

  double _scale = 0.75;
  Offset _offset = Offset.zero;
  bool _showGrid = true;
  bool _snapToGrid = true;
  CanvasMode _mode = CanvasMode.select;
  CableType _selectedCableType = CableType.straight;

  // ─── Getters ──────────────────────────────────────────────────

  double get scale => _scale;
  Offset get offset => _offset;
  bool get showGrid => _showGrid;
  bool get snapToGrid => _snapToGrid;
  CanvasMode get mode => _mode;
  CableType get selectedCableType => _selectedCableType;

  // ─── Zoom ─────────────────────────────────────────────────────

  void setScale(double scale) {
    _scale = CanvasUtils.clampScale(scale);
    notifyListeners();
  }

  void zoomIn() {
    _scale = CanvasUtils.clampScale(_scale * 1.2);
    notifyListeners();
  }

  /// Center the canvas viewport dynamically on a list of points (e.g. devices or blueprints).
  void centerOnOffsets(List<Offset> offsets, Size viewportSize) {
    if (offsets.isEmpty) return;
    
    double minX = offsets.first.dx;
    double maxX = offsets.first.dx;
    double minY = offsets.first.dy;
    double maxY = offsets.first.dy;
    
    for (var offset in offsets) {
      if (offset.dx < minX) minX = offset.dx;
      if (offset.dx > maxX) maxX = offset.dx;
      if (offset.dy < minY) minY = offset.dy;
      if (offset.dy > maxY) maxY = offset.dy;
    }
    
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    
    final s = 0.75;
    final dx = -centerX * s + viewportSize.width / 2;
    final dy = -centerY * s + viewportSize.height / 2;
    
    transformController.value = Matrix4.identity()
      // ignore: deprecated_member_use
      ..translate(dx, dy)
      // ignore: deprecated_member_use
      ..scale(s);
    _scale = s;
    notifyListeners();
  }

  /// Reset the canvas to the default center (5000, 5000).
  void resetToCenter(Size viewportSize) {
    final s = 0.75;
    final dx = -5000.0 * s + viewportSize.width / 2;
    final dy = -5000.0 * s + viewportSize.height / 2;
    transformController.value = Matrix4.identity()
      // ignore: deprecated_member_use
      ..translate(dx, dy)
      // ignore: deprecated_member_use
      ..scale(s);
    _scale = s;
    notifyListeners();
  }

  void zoomOut() {
    _scale = CanvasUtils.clampScale(_scale / 1.2);
    notifyListeners();
  }

  void resetZoom() {
    _scale = 1.0;
    notifyListeners();
  }

  // ─── Pan ──────────────────────────────────────────────────────

  void setOffset(Offset offset) {
    _offset = offset;
    notifyListeners();
  }

  void pan(Offset delta) {
    _offset += delta;
    notifyListeners();
  }

  void resetView() {
    _scale = 1.0;
    _offset = Offset.zero;
    notifyListeners();
  }

  // ─── Grid ─────────────────────────────────────────────────────

  void toggleGrid() {
    _showGrid = !_showGrid;
    notifyListeners();
  }

  void toggleSnapToGrid() {
    _snapToGrid = !_snapToGrid;
    notifyListeners();
  }

  // ─── Mode ─────────────────────────────────────────────────────

  void setMode(CanvasMode mode) {
    _mode = mode;
    notifyListeners();
  }

  void setSelectedCableType(CableType type) {
    _selectedCableType = type;
    notifyListeners();
  }

  void resetMode() {
    _mode = CanvasMode.select;
    notifyListeners();
  }
}
