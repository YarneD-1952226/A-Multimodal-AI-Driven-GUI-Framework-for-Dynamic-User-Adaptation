import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class Event {
  String eventType;
  String source;
  String? targetElement;
  Map<String, dynamic>? coordinates;
  double confidence;
  Map<String, dynamic> metadata;
  late String timestamp;
  late String userId;

  Event({
    required this.eventType,
    required this.source,
    this.targetElement,
    this.coordinates,
    this.confidence = 1.0,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType,
      'source': source,
      'target_element': targetElement,
      'coordinates': coordinates,
      'confidence': confidence,
      'metadata': metadata,
      'timestamp': timestamp,
      'user_id': userId,
    };
  }
}

class UserProfile {
  String userId;
  Map<String, dynamic> accessibilityNeeds;
  Map<String, dynamic> inputPreferences;
  Map<String, dynamic> uiPreferences;
  List<Map<String, dynamic>> interactionHistory;

  UserProfile({
    required this.userId,
    required this.accessibilityNeeds,
    required this.inputPreferences,
    required this.uiPreferences,
    required this.interactionHistory,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'accessibility_needs': accessibilityNeeds,
      'input_preferences': inputPreferences,
      'ui_preferences': uiPreferences,
      'interaction_history': interactionHistory,
    };
  }
}

class UIAdaptation {
  String action;
  String reason;
  String target;
  String? mode;
  dynamic value;

  UIAdaptation({
    required this.action,
    required this.reason,
    required this.target,
    this.mode,
    this.value,
  });

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'reason': reason,
      'target': target,
      'mode': mode,
      'value': value,
    };
  }

  factory UIAdaptation.fromJson(Map<String, dynamic> json) {
    return UIAdaptation(
      action: json['action'],
      reason: json['reason'],
      target: json['target'],
      mode: json['mode'],
      value: json['value'],
    );
  }
}

class AdaptiveUIAdapter {
  final String backendUrl = 'http://localhost:8000';
  final String wsUrl = 'ws://localhost:8000/ws/adapt';
  WebSocketChannel? channel;
  Function(List<UIAdaptation>)? onAdaptations;
  String userId;

  AdaptiveUIAdapter(this.userId, {this.onAdaptations}) {
    channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    channel!.stream.listen((data) {
      if (onAdaptations != null) {
        onAdaptations!(
          List<UIAdaptation>.from(
            jsonDecode(data)['adaptations'].map(
              (adaptation) => UIAdaptation.fromJson(adaptation),
            ),
          ),
        );
      }
    });
  }

  Future checkProfile() async {
    try {
      final response = await http.get(Uri.parse('$backendUrl/profile/$userId'));
      return response.statusCode == 200 &&
          !jsonDecode(response.body).containsKey('error');
    } catch (e) {
      return false;
    }
  }

  Future createProfile(UserProfile profileData) async {
    try {
      await http.post(
        Uri.parse('$backendUrl/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(profileData.toJson()),
      );
    } catch (e) {}
  }

  Future getProfile() async {
    try {
      final r = await http.get(Uri.parse('$backendUrl/profile/$userId'));
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (_) {}
    return null;
  }

  Future updateProfile(UserProfile profileData) async {
    try {
      await http.post(
        Uri.parse('$backendUrl/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(profileData.toJson()),
      );
    } catch (_) {}
  }

  void sendEvent(Event eventData) {
    eventData.timestamp = DateTime.now().toIso8601String();
    eventData.userId = userId;
    channel!.sink.add(jsonEncode(eventData.toJson()));
  }

  void dispose() {
    channel!.sink.close();
  }

  // Extensibility: Add new modality handlers
  void sendEyeTrackingEvent(String target, Map<String, double> gazeCoords) {
    sendEvent(
      Event(
        eventType: 'eye_tracking',
        source: 'gaze',
        targetElement: target,
        coordinates: gazeCoords,
        confidence: 1.0,
      ),
    );
  }
}
