import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/rendering.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: ArtExplorerScreen());
  }
}

class ArtExplorerScreen extends StatefulWidget {
  const ArtExplorerScreen({super.key});

  @override
  _ArtExplorerScreenState createState() => _ArtExplorerScreenState();
}

class _ArtExplorerScreenState extends State<ArtExplorerScreen> {
  List<Map<String, dynamic>> cards = List.generate(
    // UI metadata
    10,
    (index) => {
      'id': index,
      'title': 'Artwork ${index + 1}',
      'description': 'By Artist ${index + 1}',
      'cardScale': 1.0,
      'buttonScale': 1.0,
      'buttonOffset': Offset(0, 0),
      'textFontSize': 16.0,
      'textContrast': 'normal',
      'buttonContrast': 'normal',
    },
  );
  final String userId = 'user_123';
  final File eventLog = File('events.jsonl');
  int scrollFriction = 40; // Default scroll speed (lower = faster)

  // Log user events to a file and adapt UI based on events
  // This function logs events like taps, scrolls, and misses
  void logEventAndAdapt(
    String eventType,
    String targetElement,
    Offset? coordinates,
  ) async {
    final event = {
      'event_type': eventType,
      'source': 'touch',
      'timestamp': DateTime.now().toIso8601String(),
      'user_id': userId,
      'target_element': targetElement,
      if (coordinates != null)
        'coordinates': {'x': coordinates.dx, 'y': coordinates.dy},
    };
    await eventLog.writeAsString(
      '${jsonEncode(event)}\n',
      mode: FileMode.append,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event: $eventType on $targetElement'),
          duration: Duration(seconds: 1),
        ),
      );
    }
    adapt(eventType, targetElement);
  }

  // BACKEND INTERACTION MOCKUP
  // Simulates backend adaptation logic based on event type and target element
  void adapt(String eventType, String targetElement) {
    // BACKEND INTERACTION MOCKUP
    if (eventType == 'miss_tap' && targetElement.startsWith('card_')) {
      setState(() {
        cards =
            cards.map((card) {
              if (card['id'].toString() == targetElement.split('_').last) {
                return {
                  ...card,
                  'cardScale': 1.1,
                  'buttonScale': 1.3,
                  'buttonOffset': Offset(20, 0),
                  'textFontSize': 20.0,
                  'textContrast': 'high',
                  'buttonContrast': 'high',
                };
              }
              return card;
            }).toList();
      });
    } else if (eventType == 'scroll_miss') {
      setState(() {
        scrollFriction = -10; // Increase friction (slower scroll)
      });
    }
    // BACKEND INTERACTION MOCKUP
  }

  // Reset UI to default state
  void resetUI() {
    setState(() {
      cards = List.generate(
        10,
        (index) => {
          'id': index,
          'title': 'Artwork ${index + 1}',
          'description': 'By Artist ${index + 1}',
          'cardScale': 1.0,
          'buttonScale': 1.0,
          'buttonOffset': Offset(0, 0),
          'textFontSize': 16.0,
          'textContrast': 'normal',
          'buttonContrast': 'normal',
        },
      );
      scrollFriction = 40; // Reset scroll speed
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Art Explorer Demo'), centerTitle: true),
      body: GestureDetector(
        onTapDown: (details) {
          // Check if tap is outside cards (ScrollView miss-tap)
          bool hitCard = false;
          for (var card in cards) {
            final cardId = 'card_${card['id']}';
            final cardHit =
                details.localPosition.dx >= 15 &&
                details.localPosition.dx <= 365 && // Card width + margins
                details.localPosition.dy >= 0 &&
                details.localPosition.dy <= 400; // Card height
            if (cardHit) {
              logEventAndAdapt('tap', cardId, details.globalPosition);
              hitCard = true;
              break;
            }
          }
          if (!hitCard) {
            logEventAndAdapt(
              'scroll_miss',
              'scrollview',
              details.globalPosition,
            ); // precisely scroll when not hitting a card with for example gaze or tap
          }
        },
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: AdjustableScrollController(scrollFriction),
                scrollDirection: Axis.horizontal,
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    child: GestureDetector(
                      onTapDown: (details) {
                        final target = 'card_${card['id']}';
                        final hit =
                            details.localPosition.dx >= 0 &&
                            details.localPosition.dx <= 350 &&
                            details.localPosition.dy >= 0 &&
                            details.localPosition.dy <= 400;
                        logEventAndAdapt(
                          hit ? 'tap' : 'miss_tap',
                          target,
                          details.globalPosition,
                        );
                      },
                      child: Transform.scale(
                        scale: card['cardScale'],
                        child: Card(
                          color:
                              card['textContrast'] == 'high'
                                  ? Colors.white
                                  : Colors.grey[200],
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/placeholder.jpg',
                                  height: 200,
                                  width: 200,
                                  fit: BoxFit.cover,
                                ),
                                Text(
                                  card['title'],
                                  style: TextStyle(
                                    fontSize: card['textFontSize'],
                                    color:
                                        card['textContrast'] == 'high'
                                            ? Colors.black
                                            : Colors.grey[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  card['description'],
                                  style: TextStyle(
                                    fontSize: card['textFontSize'] - 2,
                                    color:
                                        card['textContrast'] == 'high'
                                            ? Colors.black
                                            : Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Transform.translate(
                                      offset: card['buttonOffset'],
                                      child: Transform.scale(
                                        scale: card['buttonScale'],
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                card['buttonContrast'] == 'high'
                                                    ? Colors.black
                                                    : Colors.blue,
                                            foregroundColor:
                                                card['buttonContrast'] == 'high'
                                                    ? Colors.white
                                                    : Colors.white,
                                          ),
                                          onPressed:
                                              () => logEventAndAdapt(
                                                'tap',
                                                'button_play_${card['id']}',
                                                null,
                                              ),
                                          child: Text('Play'),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Transform.translate(
                                      offset: card['buttonOffset'],
                                      child: Transform.scale(
                                        scale: card['buttonScale'],
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                card['buttonContrast'] == 'high'
                                                    ? Colors.black
                                                    : Colors.blue,
                                            foregroundColor:
                                                card['buttonContrast'] == 'high'
                                                    ? Colors.white
                                                    : Colors.white,
                                          ),
                                          onPressed:
                                              () => logEventAndAdapt(
                                                'tap',
                                                'button_info_${card['id']}',
                                                null,
                                              ),
                                          child: Text('Info'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.all(10),
              child: ElevatedButton(onPressed: resetUI, child: Text('Reset')),
            ),
          ],
        ),
      ),
    );
  }
}

// AdjustableScrollController to adjust scroll speed
// This controller allows for a custom scroll speed based on user input
class AdjustableScrollController extends ScrollController {
  AdjustableScrollController([int extraScrollSpeed = 40]) {
    super.addListener(() {
      ScrollDirection scrollDirection = super.position.userScrollDirection;
      if (scrollDirection != ScrollDirection.idle) {
        double scrollEnd =
            super.offset +
            (scrollDirection == ScrollDirection.reverse
                ? extraScrollSpeed
                : -extraScrollSpeed);
        scrollEnd = min(
          super.position.maxScrollExtent,
          max(super.position.minScrollExtent, scrollEnd),
        );
        jumpTo(scrollEnd);
      }
    });
  }
}
