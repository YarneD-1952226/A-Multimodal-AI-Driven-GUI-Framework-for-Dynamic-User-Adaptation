import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:frontend/day3_adapter_layer.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(create: (_) => AdaptationState(), child: MyApp()),
  );
}

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
  late AdaptiveScrollController scrollController;
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

  // Initialize the custom adaptive scroll controller
  @override
  void initState() {
    super.initState();
    scrollController = AdaptiveScrollController();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  // Create a JSON contract for user events for backend processing
  Map<String, dynamic> createJsonEvent({
    required String eventType,
    required String source,
    required String userId,
    String? targetElement,
    Offset? coordinates,
    double confidence = 1.0,
    Map<String, dynamic>? metadata,
  }) {
    return {
      'event_type': eventType,
      'source': source,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'user_id': userId,
      if (targetElement != null) 'target_element': targetElement,
      if (coordinates != null)
        'coordinates': {'x': coordinates.dx, 'y': coordinates.dy},
      'confidence': confidence,
      'metadata':
          metadata ?? {'command': null, 'gesture_type': null, 'key': null},
    };
  }

  // Log user events to a file and adapt UI based on events
  // This function logs events like taps, scrolls, and misses
  void logEventAndAdapt(
    String eventType,
    String targetElement,
    Offset? coordinates,
  ) async {
    final jsonEvent = createJsonEvent(
      eventType: eventType,
      source: 'touch',
      userId: userId,
      targetElement: targetElement,
      coordinates: coordinates,
    );

    print('Sending event to backend: ${jsonEncode(jsonEvent)}');

    // Log the event to a file
    await eventLog.writeAsString(
      '${jsonEncode(jsonEvent)}\n',
      mode: FileMode.append,
    );

    //snackbar to show event logging
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Event logged: $eventType on $targetElement'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final adaptations = await sendEventToBackend(jsonEvent);

      print('Received adaptations: $adaptations');

      // Apply adaptations locally in adapt()
      for (var adaptation in adaptations) {
        adapt(adaptation['action'], adaptation['target'], adaptation['value']);
      }
    } catch (e) {
      print('Error contacting backend: $e');
    }
  }

  // Send event to backend and get adaptations
  Future<List<Map<String, dynamic>>> sendEventToBackend(
    Map<String, dynamic> jsonEvent,
  ) async {
    final response = await http.post(
      Uri.parse('http://localhost:8000/context'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(jsonEvent),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['adaptations']);
    } else {
      throw Exception('Failed to get adaptations from backend');
    }
  }

  // BACKEND INTERACTION MOCKUP
  // Simulates backend adaptation logic based on event type and target element
  void adapt(String action, String targetElement, [dynamic value]) {
    if (action == 'increase_size') {
      setState(() {
        cards =
            cards.map((card) {
              if (card['id'].toString() == targetElement.split('_').last) {
                return {...card, 'buttonScale': value ?? 1.5};
              }
              return card;
            }).toList();
      });
    } else if (action == 'adjust_scroll_speed') {
      setState(() {
        scrollController.updateScrollSpeed(value ?? 40);
      });
    }
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
      scrollController.updateScrollSpeed(40);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Art Explorer Demo'), centerTitle: true),
      body: GestureDetector(
        onTapDown: (details) {
          bool hitCard = false;
          for (var card in cards) {
            final cardId = 'card_${card['id']}';
            final cardHit =
                details.localPosition.dx >= 15 &&
                details.localPosition.dx <= 365 &&
                details.localPosition.dy >= 0 &&
                details.localPosition.dy <= 400;
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
            );
          }
        },
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: scrollController,
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
                                AdaptiveText(
                                  text: card['title'],
                                  scale: card['textFontSize'] / 16,
                                  color:
                                      card['textContrast'] == 'high'
                                          ? Colors.black
                                          : Colors.grey[800]!,
                                  align: TextAlign.center,
                                ),
                                AdaptiveText(
                                  text: card['description'],
                                  scale: (card['textFontSize'] - 2) / 16,
                                  color:
                                      card['textContrast'] == 'high'
                                          ? Colors.black
                                          : Colors.grey[600]!,
                                  align: TextAlign.center,
                                ),
                                SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AdaptiveButton(
                                      label: 'Play',
                                      onPressed:
                                          () => logEventAndAdapt(
                                            'tap',
                                            'button_play_${card['id']}',
                                            null,
                                          ),
                                      scale: card['buttonScale'],
                                      offset: card['buttonOffset'],
                                      backgroundColor:
                                          card['buttonContrast'] == 'high'
                                              ? Colors.black
                                              : Colors.blue,
                                    ),
                                    SizedBox(width: 10),
                                    AdaptiveButton(
                                      label: 'Info',
                                      onPressed:
                                          () => logEventAndAdapt(
                                            'tap',
                                            'button_info_${card['id']}',
                                            null,
                                          ),
                                      scale: card['buttonScale'],
                                      offset: card['buttonOffset'],
                                      backgroundColor:
                                          card['buttonContrast'] == 'high'
                                              ? Colors.black
                                              : Colors.blue,
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

// --- Adaptive UI Components ---

// AdaptiveButton to display buttons with adaptive scaling and contrast
class AdaptiveButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final double scale;
  final Offset offset;
  final Color backgroundColor;
  final Color foregroundColor;
  final double fontSize;

  const AdaptiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.scale = 1.0,
    this.offset = Offset.zero,
    this.backgroundColor = Colors.blue,
    this.foregroundColor = Colors.white,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Padding(
        padding: EdgeInsets.only(left: offset.dx, top: offset.dy),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
          ),
          onPressed: onPressed,
          child: Text(label, style: TextStyle(fontSize: fontSize)),
        ),
      ),
    );
  }
}

// AdaptiveText to display text with adaptive scaling and contrast
class AdaptiveText extends StatelessWidget {
  final String text;
  final double scale;
  final Color color;
  final TextAlign align;

  const AdaptiveText({
    required this.text,
    this.scale = 1.0,
    this.color = Colors.black,
    this.align = TextAlign.left,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: TextStyle(fontSize: 16 * scale, color: color),
    );
  }
}

// AdaptiveCardList to display a list of images with adaptive scaling
// class AdaptiveCardList extends StatelessWidget {
//   final List<String> imageUrls;
//   final double cardScale;
//   final double spacing;

//   const AdaptiveCardList({
//     required this.imageUrls,
//     this.cardScale = 1.0,
//     this.spacing = 8.0,
//     super.key,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 180 * cardScale,
//       child: ListView.separated(
//         scrollDirection: Axis.horizontal,
//         itemCount: imageUrls.length,
//         separatorBuilder: (_, __) => SizedBox(width: spacing),
//         itemBuilder: (context, index) {
//           return Transform.scale(
//             scale: cardScale,
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(12),
//               child: Image.network(
//                 imageUrls[index],
//                 width: 120,
//                 height: 180,
//                 fit: BoxFit.cover,
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// AdaptiveScrollController to adjust scroll speed
// This controller allows for a custom scroll speed based on user input
class AdaptiveScrollController extends ScrollController {
  int scrollSpeed = 40; // Default scroll speed (lower = faster)

  AdaptiveScrollController() : super() {
    addListener(_scrollListener);
  }

  void updateScrollSpeed(int newSpeed) {
    scrollSpeed = newSpeed;
    notifyListeners();
  }

  void _scrollListener() {
    if (!hasClients) return;
    ScrollDirection scrollDirection = position.userScrollDirection;
    if (scrollDirection != ScrollDirection.idle) {
      double scrollEnd =
          offset +
          (scrollDirection == ScrollDirection.reverse
              ? scrollSpeed
              : -scrollSpeed);
      scrollEnd = min(
        position.maxScrollExtent,
        max(position.minScrollExtent, scrollEnd),
      );
      jumpTo(scrollEnd);
    }
  }

  @override
  void dispose() {
    removeListener(_scrollListener);
    super.dispose();
  }
}
