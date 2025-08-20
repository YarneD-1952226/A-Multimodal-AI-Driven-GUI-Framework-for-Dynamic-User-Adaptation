import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DebugScreen(),
      title: 'Debugging Interface',
      theme: ThemeData(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white, // Set text color to white
          ),
        ),
      ),
    );
  }
}

class DebugScreen extends StatefulWidget {
  @override
  _DebugScreenState createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  var channel = WebSocketChannel.connect(
    Uri.parse('ws://localhost:8000/ws/adapt'),
  );
  List<Map<String, dynamic>> adaptations = [];
  List<Map<String, dynamic>> historyEntries = [];
  String profileJson = '';
  String eventJson = '';
  bool isLoading = false;

  // Pre-existing profiles
  final Map<String, String> preProfiles = {
    'Motor Impaired':
        '{"user_id": "user_123", "accessibility_needs": {"motor_impaired": true}, "input_preferences": {"preferred_modality": "voice"}}',
    'Hands-Free':
        '{"user_id": "user_124", "accessibility_needs": {"hands_free_preferred": true}}',
  };

  // Pre-existing events/commands
  final Map<String, String> preEvents = {
    'Miss-Tap on Play':
        '{"event_type": "miss_tap", "source": "touch", "timestamp": "2025-07-30T00:00:00Z", "user_id": "user_123", "target_element": "button_play"}',
    'Voice Play Command':
        '{"event_type": "voice", "source": "voice", "timestamp": "2025-07-30T00:00:00Z", "user_id": "user_123", "metadata": {"command": "play"}}',
    'Gesture Point':
        '{"event_type": "gesture", "source": "gesture", "timestamp": "2025-07-30T00:00:00Z", "user_id": "user_123", "metadata": {"gesture_type": "point"}}',
  };

  @override
  void initState() {
    super.initState();
    getHistory();
    channel.stream.listen((data) async {
      setState(() {
        adaptations = List<Map<String, dynamic>>.from(
          jsonDecode(data)['adaptations'],
        );
        isLoading = false;
      });
      getHistory();
    });
  }

  Future<void> getHistory() async {
    final entries = await getFullHistory();
    setState(() {
      historyEntries = entries;
    });
  }

  String _prettyJson(dynamic json) {
    return JsonEncoder.withIndent('  ').convert(json);
  }

  Widget _buildProfileVisualization(String profileJson) {
    final profile = jsonDecode(profileJson);

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              Icons.person,
              Colors.blue,
              'User: ${profile['user_id'] ?? 'Unknown'}',
              isTitle: true,
            ),
            SizedBox(height: 12),
            if (profile['accessibility_needs'] != null) ...[
              _buildSectionHeader(
                Icons.accessibility,
                Colors.green,
                'Accessibility Needs:',
              ),
              ..._buildNestedItems(
                profile['accessibility_needs'],
                Icons.check_circle,
                Colors.orange,
              ),
              SizedBox(height: 12),
            ],
            if (profile['input_preferences'] != null) ...[
              _buildSectionHeader(
                Icons.settings,
                Colors.purple,
                'Input Preferences:',
              ),
              ..._buildNestedItems(
                profile['input_preferences'],
                Icons.star,
                Colors.amber,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventVisualization(String eventJson) {
    final event = jsonDecode(eventJson);

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              Icons.event,
              Colors.blue,
              'Event Type: ${event['event_type'] ?? 'Unknown'}',
              isTitle: true,
            ),
            SizedBox(height: 12),
            _buildInfoRow(
              Icons.touch_app,
              Colors.green,
              'Source: ${event['source'] ?? 'Unknown'}',
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.access_time,
              Colors.orange,
              'Timestamp: ${event['timestamp'] ?? 'Unknown'}',
            ),
            SizedBox(height: 8),
            if (event['user_id'] != null)
              _buildInfoRow(
                Icons.person,
                Colors.purple,
                'User ID: ${event['user_id']}',
              ),
            SizedBox(height: 8),

            if (event['target_element'] != null)
              _buildInfoRow(
                Icons.my_location,
                Colors.red,
                'Target Element: ${event['target_element']}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    Color color,
    String text, {
    bool isTitle = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: color),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
            fontSize: isTitle ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, Color color, String title) {
    return Row(
      children: [
        Icon(icon, color: color),
        SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  List<Widget> _buildNestedItems(
    Map<String, dynamic> items,
    IconData icon,
    Color color,
  ) {
    return items.entries
        .map(
          (entry) => Padding(
            padding: EdgeInsets.only(left: 32, top: 4),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                SizedBox(width: 4),
                Text('${entry.key.replaceAll('_', ' ')}: ${entry.value}'),
              ],
            ),
          ),
        )
        .toList();
  }

  String _formatAdaptations(List<Map<String, dynamic>> adaptations) {
    if (adaptations.isEmpty) return 'No adaptations suggested.';
    return adaptations
        .map((adapt) {
          String action = adapt['action'];
          String target = adapt['target'] ?? 'UI element';
          String reason = adapt['reason'] ?? 'No reason provided';
          String details = '';

          switch (action) {
            case 'increase_size':
              details = 'Enlarge $target by ${adapt['value']}x';
              break;
            case 'reposition_element':
              var offset = adapt['offset'];
              details = 'Move $target to (${offset['x']}, ${offset['y']})';
              break;
            case 'increase_contrast':
              details =
                  'Increase contrast for $target to ${adapt['mode'] ?? adapt['value']} mode';
              break;
            case 'adjust_scroll_speed':
              details = 'Set scroll speed to ${adapt['value']} for $target';
              break;
            case 'switch_mode':
              details = 'Switch to ${adapt['mode'] ?? adapt['value']} mode';
              break;
            case 'trigger_button':
              details = 'Trigger $target button';
              break;
            case 'simplify_layout':
              details = 'Simplify $target to ${adapt['value']} layout';
              break;
            default:
              details = 'Perform $action on $target';
          }
          return '$details because: $reason';
        })
        .join('\n');
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'increase_size':
        return Icons.zoom_out_map;
      case 'reposition_element':
        return Icons.open_with;
      case 'increase_contrast':
        return Icons.brightness_high;
      case 'adjust_scroll_speed':
        return Icons.speed;
      case 'switch_mode':
        return Icons.swap_horiz;
      case 'trigger_button':
        return Icons.play_arrow;
      case 'simplify_layout':
        return Icons.grid_off;
      default:
        return Icons.settings;
    }
  }

  void updateProfile(String profile) {
    setState(() => profileJson = profile);
  }

  void updateEvent(String event) {
    setState(() => eventJson = event);
  }

  void sendEvent() async {
    setState(() => isLoading = true);
    adaptations.clear();

    await sendProfile();

    // Check if channel is open, else try to reconnect
    // if (channel.closeCode != null) {
    //   await _reconnectChannel();
    // }

    // bool sent = false;
    try {
      channel.sink.add(eventJson);

      // Wait for response with timeout
      //await channel.stream.first.timeout(Duration(seconds: 5)).then((data) {
      // Already handled in stream.listen, so just mark as sent
      // sent = true;
      //});
    } on TimeoutException {
      setState(() {
        // isLoading = false;
        //history +=
        //    '\n[Error] Backend did not respond in time (timeout after 5s).';
      });
    } catch (e) {
      setState(() {
        // isLoading = false;
        //history += '\n[Error] Failed to send event: $e';
      });
    }
    // if (!sent) {
    //   setState(() {
    //     isLoading = false;
    //   });
    // }
  }

  Future<List<Map<String, dynamic>>> getFullHistory() async {
    try {
      final response = await HttpClient().getUrl(
        Uri.parse('http://localhost:8000/full_history'),
      );
      final res = await response.close();
      if (res.statusCode == 200) {
        final String jsonString = await res.transform(utf8.decoder).join();
        print(jsonDecode(jsonString)['history']);
        return List<Map<String, dynamic>>.from(
          jsonDecode(jsonString)['history'],
        );
      } else {
        print('Failed to fetch history. Status code: ${res.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching history: $e');
      return [];
    }
  }

  Future<void> sendProfile() async {
    if (profileJson.isEmpty) {
      print('No profile provided');
      return;
    }
    try {
      final Uri uri = Uri.parse('http://localhost:8000/profile');
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.add(utf8.encode(profileJson));
      final response = await request.close();
      if (response.statusCode == 200) {
        print('Profile updated successfully');
      } else {
        print('Failed to update profile. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating profile: $e');
    }
  }

  // Future<void> _reconnectChannel() async {
  //   try {
  //     channel.sink.close();
  //   } catch (_) {}
  //   await Future.delayed(Duration(milliseconds: 500));
  //   setState(() {
  //     // Recreate the channel
  //     // ignore: invalid_use_of_protected_member
  //     channel = WebSocketChannel.connect(
  //       Uri.parse('ws://localhost:8000/ws/adapt'),
  //     );
  //     // Re-attach listener
  //     channel.stream.listen((data) {
  //       setState(() {
  //         adaptations = List<Map<String, dynamic>>.from(
  //           jsonDecode(data)['adaptations'],
  //         );
  //         // Add to history as structured data instead of string
  //         Map<String, dynamic> historyEntry = {
  //           'timestamp': DateTime.now().toIso8601String(),
  //           'event': jsonDecode(eventJson),
  //           'adaptations': adaptations,
  //         };
  //         historyEntries.insert(0, historyEntry);
  //         if (historyEntries.length > 10) {
  //           historyEntries.removeLast();
  //         }
  //         isLoading = false;
  //       });
  //     });
  //   });
  // }

  _flowStep(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 16)),
        SizedBox(width: 12),
      ],
    );
  }

  _flowArrow({bool isForward = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isForward ? Icons.arrow_forward : Icons.arrow_back,
          color: Colors.grey,
          size: 24,
        ),
        SizedBox(width: 12),
      ],
    );
  }

  _flowPlus() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.add, color: Colors.grey, size: 24),
        SizedBox(width: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Backend Interface Demo')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.dashboard_customize, color: Colors.blue, size: 36),
                SizedBox(width: 12),
                Text(
                  "AI-Driven Adaptation Backend Interface",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // Configuration Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Configuration",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User Profile',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      onChanged: (val) => profileJson = val,
                                      decoration: InputDecoration(
                                        labelText: 'Profile JSON',
                                        hintText: 'Enter profile JSON',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        prefixIcon: Icon(Icons.person),
                                      ),
                                      maxLines: 3,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => updateProfile(profileJson),
                                    icon: Icon(Icons.upload),
                                    label: Text('Apply'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 18),
                              DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Predefined Profiles',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                items: preProfiles.keys
                                    .map(
                                      (key) => DropdownMenuItem(
                                        value: preProfiles[key],
                                        child: Text(key),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) => updateProfile(val!),
                              ),
                              SizedBox(height: 12),
                              ExpansionTile(
                                title: Text(
                                  'Current Profile',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                initiallyExpanded: true,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SelectableText(
                                      _prettyJson(
                                        jsonDecode(
                                          profileJson.isEmpty
                                              ? '{}'
                                              : profileJson,
                                        ),
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Profile Visualization:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  profileJson.isEmpty
                                      ? Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            'No profile loaded.',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      : _buildProfileVisualization(profileJson),
                                  SizedBox(height: 8),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 24),
                        // Event Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Input Event',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      onChanged: (val) => eventJson = val,
                                      decoration: InputDecoration(
                                        labelText: 'Event JSON',
                                        hintText: 'Enter event JSON',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        prefixIcon: Icon(Icons.event),
                                      ),
                                      maxLines: 3,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => updateEvent(eventJson),
                                    icon: Icon(Icons.upload),
                                    label: Text('Apply'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 18),
                              DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Predefined Events',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                items: preEvents.keys
                                    .map(
                                      (key) => DropdownMenuItem(
                                        value: preEvents[key],
                                        child: Text(key),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) => updateEvent(val!),
                              ),
                              SizedBox(height: 12),
                              ExpansionTile(
                                title: Text(
                                  'Current Event',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                initiallyExpanded: true,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SelectableText(
                                      _prettyJson(
                                        jsonDecode(
                                          eventJson.isEmpty ? '{}' : eventJson,
                                        ),
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Event Visualization:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  eventJson.isEmpty
                                      ? Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            'No event loaded.',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      : _buildEventVisualization(eventJson),
                                  SizedBox(height: 8),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 32),

            // Backend Flow Visualization
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.indigo[50],
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                child: Column(
                  children: [
                    Text(
                      'AI/Backend Flow Visualization',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _flowStep(Icons.touch_app, 'Event Input', Colors.red),
                          _flowPlus(),
                          _flowStep(Icons.person, 'User Profile', Colors.green),
                          _flowPlus(),
                          _flowStep(
                            Icons.history,
                            'Interaction History',
                            Colors.orange,
                          ),
                          _flowArrow(isForward: true),
                          _flowStep(Icons.smart_toy, 'SIF', Colors.purple),
                          _flowArrow(isForward: true),
                          _flowStep(
                            Icons.auto_awesome,
                            'Adaptations',
                            Colors.blue,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 28),

            // Adaptations Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.blue, size: 28),
                        SizedBox(width: 8),
                        Text(
                          "Adaptations",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        ElevatedButton.icon(
                          onPressed: sendEvent,
                          icon: Icon(Icons.lightbulb),
                          label: Text('Get Suggestions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Backend Response (Adaptations):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    if (isLoading)
                      Center(child: CircularProgressIndicator())
                    else if (adaptations.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No adaptations suggested.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: adaptations.length,
                        separatorBuilder: (_, __) => SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final adapt = adaptations[idx];
                          return Card(
                            color: Colors.blue[50],
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Icon(
                                _getActionIcon(adapt['action']),
                                color: Colors.blue[700],
                                size: 36,
                              ),
                              title: Text(
                                _formatAdaptations([adapt]),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'AI suggestion for accessibility',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 28),

            // Interaction History Section
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history, color: Colors.orange, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'Interaction History',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              historyEntries.clear();
                              adaptations = [];
                            });
                          },
                          icon: Icon(Icons.delete),
                          label: Text('Clear History'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[400],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    if (historyEntries.isEmpty)
                      Card(
                        color: Colors.grey[100],
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.grey),
                              SizedBox(width: 8),
                              Text(
                                'No history yet.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: historyEntries.length,
                        itemBuilder: (context, idx) {
                          final entry = historyEntries[idx];
                          List<dynamic> interactionHistory;
                          try {
                            if (entry['interaction_history'] is String) {
                              interactionHistory = jsonDecode(
                                entry['interaction_history'],
                              );
                            } else {
                              interactionHistory =
                                  entry['interaction_history'] ?? [];
                            }
                          } catch (e) {
                            interactionHistory = [];
                          }

                          if (interactionHistory.isEmpty) {
                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 8),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No history entries available for user ${entry['user_id'] ?? 'Unknown'}.',
                                ),
                              ),
                            );
                          } else {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 8),
                                Divider(color: Colors.grey, thickness: 1),
                                Text(
                                  'User: ${entry['user_id'] ?? 'Unknown'}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                                SizedBox(height: 8),
                                SizedBox(
                                  height: 220,
                                  child: ListView.builder(
                                    itemCount: interactionHistory.length,
                                    itemBuilder: (context, idx) {
                                      final historyItem =
                                          interactionHistory[idx] is String
                                          ? json.decode(interactionHistory[idx])
                                          : interactionHistory[idx];

                                      return Card(
                                        margin: EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        elevation: 2,
                                        color: Colors.orange[50],
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.access_time,
                                                    color: Colors.blue,
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 8),
                                                  if (historyItem['timestamp'] !=
                                                      null)
                                                    Text(
                                                      DateTime.parse(
                                                            historyItem['timestamp'],
                                                          )
                                                          .toLocal()
                                                          .toString()
                                                          .substring(0, 19),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              SizedBox(height: 8),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Icon(
                                                    Icons.person,
                                                    color: Colors.green,
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'User: ${historyItem['user_id'] ?? 'Unknown'}',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 8),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Icon(
                                                    Icons.event,
                                                    color: Colors.green,
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Event: ${historyItem['event_type'] ?? 'Unknown'}',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                        if (historyItem['source'] !=
                                                            null)
                                                          Text(
                                                            'Source: ${historyItem['source'] ?? 'Unknown'}',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 8),
                                              if (historyItem['adaptations'] !=
                                                  null)
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      Icons.auto_awesome,
                                                      color: Colors.purple,
                                                      size: 18,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Adaptations:',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                          SizedBox(height: 2),
                                                          if (historyItem['adaptations']
                                                              .isEmpty)
                                                            Text(
                                                              'No adaptations suggested',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                            )
                                                          else
                                                            ...historyItem['adaptations']
                                                                .map<Widget>(
                                                                  (
                                                                    adapt,
                                                                  ) => Padding(
                                                                    padding:
                                                                        EdgeInsets.symmetric(
                                                                          vertical:
                                                                              1,
                                                                        ),
                                                                    child: Row(
                                                                      children: [
                                                                        Icon(
                                                                          _getActionIcon(
                                                                            adapt['action'],
                                                                          ),
                                                                          size:
                                                                              14,
                                                                          color:
                                                                              Colors.orange,
                                                                        ),
                                                                        SizedBox(
                                                                          width:
                                                                              4,
                                                                        ),
                                                                        Expanded(
                                                                          child: Text(
                                                                            _formatAdaptations([
                                                                              adapt,
                                                                            ]),
                                                                            style: TextStyle(
                                                                              fontSize: 12,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                )
                                                                .toList(),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }
}
