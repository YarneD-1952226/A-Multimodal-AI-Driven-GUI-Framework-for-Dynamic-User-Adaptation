import 'package:flutter/material.dart';

//Data model for adaptive UI components

// Data is universal of all components??
// JSON contract??

class AdaptationData {
  final double scale;
  final double fontSize;
  final Offset positionOffset;
  final String contrast;

  AdaptationData({
    this.scale = 1.0,
    this.fontSize = 14.0,
    this.positionOffset = Offset.zero,
    this.contrast = 'normal',
  });
}

class AdaptationState extends ChangeNotifier {
  final Map<String, AdaptationData> _adaptations = {};

  AdaptationData getAdaptation(String id) =>
      _adaptations[id] ?? AdaptationData();

  void updateAdaptation(String id, AdaptationData data) {
    _adaptations[id] = data;
    notifyListeners();
  }

  void resetAdaptation(String id) {
    _adaptations.remove(id);
    notifyListeners();
  }

  void clearAll() {
    _adaptations.clear();
    notifyListeners();
  }
}
