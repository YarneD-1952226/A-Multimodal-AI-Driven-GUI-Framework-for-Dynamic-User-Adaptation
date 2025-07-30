import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: DebugScreen(), title: 'Debugging Interface');
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
  String history = '';
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
    channel.stream.listen((data) {
      setState(() {
        adaptations = List<Map<String, dynamic>>.from(
          jsonDecode(data)['adaptations'],
        );
        history +=
            '\nEvent: ${_prettyJson(jsonDecode(eventJson))}\nAdaptations:\n${_formatAdaptations(adaptations)}';
        isLoading = false;
      });
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

    // Check if channel is open, else try to reconnect
    if (channel.closeCode != null) {
      await _reconnectChannel();
    }

    // bool sent = false;
    try {
      channel.sink.add(eventJson);

      // Wait for response with timeout
      await channel.stream.first.timeout(Duration(seconds: 5)).then((data) {
        // Already handled in stream.listen, so just mark as sent
        // sent = true;
      });
    } on TimeoutException {
      setState(() {
        isLoading = false;
        //history +=
        //    '\n[Error] Backend did not respond in time (timeout after 5s).';
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        //history += '\n[Error] Failed to send event: $e';
      });
    }
    // if (!sent) {
    //   setState(() {
    //     isLoading = false;
    //   });
    // }
  }

  Future<void> _reconnectChannel() async {
    try {
      channel.sink.close();
    } catch (_) {}
    await Future.delayed(Duration(milliseconds: 500));
    setState(() {
      // Recreate the channel
      // ignore: invalid_use_of_protected_member
      channel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:8000/ws/adapt'),
      );
      // Re-attach listener
      channel.stream.listen((data) {
        setState(() {
          adaptations = List<Map<String, dynamic>>.from(
            jsonDecode(data)['adaptations'],
          );
          history +=
              '\nEvent: ${_prettyJson(jsonDecode(eventJson))}\nAdaptations:\n${_formatAdaptations(adaptations)}';
          isLoading = false;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Backend Debug Demo')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Configuration",
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Input Profile (JSON):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextField(
                        onChanged: (val) => profileJson = val,
                        decoration: InputDecoration(
                          hintText: 'Enter profile JSON',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => updateProfile(profileJson),
                        child: Text('Update Profile'),
                      ),
                      SizedBox(height: 8),
                      DropdownButton<String>(
                        hint: Text('Pre-existing Profiles'),
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
                      SizedBox(height: 8),
                      Text(
                        'Current Profile:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SelectableText(
                        _prettyJson(
                          jsonDecode(profileJson.isEmpty ? '{}' : profileJson),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Profile Visualization:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      profileJson.isEmpty
                          ? Text('No profile loaded.')
                          : _buildProfileVisualization(profileJson),
                    ],
                  ),
                ),
                VerticalDivider(width: 30, thickness: 1, color: Colors.grey),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Input Event (JSON):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextField(
                        onChanged: (val) => eventJson = val,
                        decoration: InputDecoration(
                          hintText: 'Enter event JSON',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => updateEvent(eventJson),
                        child: Text('Update Event'),
                      ),
                      SizedBox(height: 8),
                      DropdownButton<String>(
                        hint: Text('Pre-existing Events'),
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
                      SizedBox(height: 8),
                      Text(
                        'Current Event:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SelectableText(
                        _prettyJson(
                          jsonDecode(eventJson.isEmpty ? '{}' : eventJson),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Event Visualization:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      eventJson.isEmpty
                          ? Text('No event loaded.')
                          : _buildEventVisualization(eventJson),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 30),
            Text(
              "Adaptations",
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'AI/Backend Flow Visualization:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Icon(Icons.touch_app, size: 50, color: Colors.red),
                    Text('Event Input'),
                  ],
                ),
                Icon(Icons.add, size: 30),

                Column(
                  children: [
                    Icon(Icons.person, size: 50, color: Colors.green),
                    Text('User Profile'),
                  ],
                ),
                Icon(Icons.add, size: 30),
                Column(
                  children: [
                    Icon(Icons.history, size: 50, color: Colors.orange),
                    Text('Interaction History'),
                  ],
                ),
                Icon(Icons.arrow_forward, size: 30),
                Column(
                  children: [
                    Icon(Icons.smart_toy, size: 50, color: Colors.purple),
                    Text('SIF (Smart Intent Fusion)'),
                  ],
                ),
                Icon(Icons.arrow_forward, size: 30),
                Column(
                  children: [
                    Icon(Icons.auto_awesome, size: 50, color: Colors.blue),
                    Text('Adaptations'),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: sendEvent,
              child: Text('Get Suggestions'),
            ),
            SizedBox(height: 16),
            Text(
              'Backend Response (Adaptations):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (isLoading) Center(child: CircularProgressIndicator()),
            if (adaptations.isEmpty && !isLoading)
              Text('No adaptations suggested.')
            else
              Column(
                children: adaptations
                    .map(
                      (adapt) => Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Icon(
                            _getActionIcon(adapt['action']),
                            color: Colors.blue,
                            size: 40,
                          ),
                          title: Text(
                            _formatAdaptations([adapt]),
                            style: TextStyle(fontSize: 16),
                          ),
                          subtitle: Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 12,
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
                      ),
                    )
                    .toList(),
              ),
            SizedBox(height: 16),
            Text(
              'Interaction History:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(history.isEmpty ? 'No history yet.' : history),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  history = '';
                  adaptations = [];
                });
              },
              child: Text('Clear History'),
            ),
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
