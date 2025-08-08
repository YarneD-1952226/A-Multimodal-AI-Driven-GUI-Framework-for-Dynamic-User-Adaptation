import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const AdaptiveApp());
}

class AdaptiveApp extends StatelessWidget {
  const AdaptiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adaptive UI Prototype',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const AdaptiveHomePage(),
    );
  }
}

class AdaptiveHomePage extends StatefulWidget {
  const AdaptiveHomePage({super.key});

  @override
  State<AdaptiveHomePage> createState() => _AdaptiveHomePageState();
}

class _AdaptiveHomePageState extends State<AdaptiveHomePage> {
  double buttonScale = 1.0;
  Offset buttonOffset = Offset.zero;

  Future<void> sendContext(String contextType) async {
    final Map<String, dynamic> contextPayload = {
      "shaky_hand": contextType == "shaky_hand",
      "hover_without_click": contextType == "hover",
      "frequent_miss_clicks": contextType == "miss_clicks",
    };

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/adapt'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(contextPayload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        applyAdaptations(data["actions"]);
      } else {
        print("Failed to contact backend: ${response.statusCode}");
      }
    } catch (e) {
      print("Error contacting backend: $e");
      return;
    }
  }

  void applyAdaptations(List<dynamic> actions) {
    for (var action in actions) {
      if (action["target"] == "main_button") {
        setState(() {
          buttonScale = action["scale"] ?? 1.0;
          if (action["moveCloser"] == true) {
            buttonOffset = buttonOffset.translate(20, 0);
          }
        });
      }
    }
  }

  void resetAdaptations() {
    setState(() {
      buttonScale = 1.0;
      buttonOffset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adaptive UI Prototype')),
      body: Column(
        children: [
          Text("Simulate different user interaction contexts",
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          // Controls to simulate different contexts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                onPressed: () => sendContext("hover"),
                child: const Text("Hover"),
              ),
              ElevatedButton(
                onPressed: () => sendContext("shaky_hand"),
                child: const Text("Shaky Hand"),
              ),
              ElevatedButton(
                onPressed: () => sendContext("miss_clicks"),
                child: const Text("Miss Clicks"),
              ),
              ElevatedButton(
                onPressed: resetAdaptations,
                child: const Text("Reset"),
              ),
            ],
          ),
          const SizedBox(height: 20),
                    Text("UI will adapt based on your interactions",
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          // Horizontal scroll view
          SizedBox(
            height: 150,
            child: ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 10,
                itemBuilder: (context, index) {
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Item ${index + 1}',
                        style: const TextStyle(fontSize: 16),
                      ),  
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Main adaptive button
          Transform.translate(
            offset: buttonOffset,
            child: AnimatedScale(
              scale: buttonScale,
              duration: const Duration(milliseconds: 300),
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Play pressed!")),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20, 
                  ),
                  child: Text(
                    "Play",
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text("Text block")
        ],
      ),
    );
  }
}


// examples
// different platforms
// 