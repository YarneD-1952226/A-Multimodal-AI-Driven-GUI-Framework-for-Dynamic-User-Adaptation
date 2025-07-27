import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AdaptiveUIScreen(),
    );
  }
}

class AdaptiveUIScreen extends StatefulWidget {
  @override
  _AdaptiveUIScreenState createState() => _AdaptiveUIScreenState();
}

class _AdaptiveUIScreenState extends State<AdaptiveUIScreen> {
  List<Map<String, dynamic>> cards = List.generate(
    10,
    (index) => {
      'id': index,
      'title': 'Card ${index + 1}',
      'buttonScale': 1.0,
      'buttonOffset': Offset(0, 0),
    },
  );
  final String userId = 'user_123';
  final File eventLog = File('events.jsonl');

  void logEvent(String eventType, String targetElement, Offset? coordinates) async {
    final event = {
      'event_type': eventType,
      'source': 'touch',
      'timestamp': DateTime.now().toIso8601String(),
      'user_id': userId,
      'target_element': targetElement,
      if (coordinates != null) 'coordinates': {'x': coordinates.dx, 'y': coordinates.dy},
    };
    await eventLog.writeAsString('${jsonEncode(event)}\n', mode: FileMode.append);
    if (eventType == 'miss_tap') {
      setState(() {
        cards = cards.map((card) {
          if (card['id'].toString() == targetElement.split('_').last) {
            return {...card, 'buttonScale': 1.5, 'buttonOffset': Offset(20, 0)};
          }
          return card;
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Adaptive UI Demo')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];
                return Container(
                  width: 300,
                  margin: EdgeInsets.all(10),
                  child: GestureDetector(
                    onTapDown: (details) {
                      final target = 'card_${card['id']}';
                      final hit = details.localPosition.dx >= 0 &&
                          details.localPosition.dx <= 200 &&
                          details.localPosition.dy >= 0 &&
                          details.localPosition.dy <= 300;
                      logEvent(hit ? 'tap' : 'miss_tap', target, details.globalPosition);
                    },
                    child: Card(
                      child: Column(
                        children: [
                          Image.asset('assets/placeholder.jpg', height: 100, fit: BoxFit.cover),
                          Text(card['title']),
                          Transform.translate(
                            offset: card['buttonOffset'],
                            child: Transform.scale(
                              scale: card['buttonScale'],
                              child: ElevatedButton(
                                onPressed: () => logEvent('tap', 'button_play_${card['id']}', null),
                                child: Text('Play'),
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: card['buttonOffset'],
                            child: Transform.scale(
                              scale: card['buttonScale'],
                              child: ElevatedButton(
                                onPressed: () => logEvent('tap', 'button_info_${card['id']}', null),
                                child: Text('Info'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                cards = List.generate(
                  10,
                  (index) => {
                    'id': index,
                    'title': 'Card ${index + 1}',
                    'buttonScale': 1.0,
                    'buttonOffset': Offset(0, 0),
                  },
                );
              });
            },
            child: Text('Reset'),
          ),
        ],
      ),
    );
  }
}