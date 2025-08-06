import 'dart:math' as math;
import 'adapter_layer.dart';
import 'package:flutter/material.dart';

void main() => runApp(AdaptiveSmartHomeApp());

class AdaptiveSmartHomeApp extends StatefulWidget {
  @override
  _AdaptiveSmartHomeAppState createState() => _AdaptiveSmartHomeAppState();
}

class _AdaptiveSmartHomeAppState extends State<AdaptiveSmartHomeApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _changeTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SmartHomeScreen(onThemeChange: _changeTheme),
      theme: _buildNormalTheme(),
      darkTheme: _buildContrastTheme(),
      themeMode: _themeMode,
    );
  }

  ThemeData _buildNormalTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.blue,
      primaryColor: Colors.blue,
      scaffoldBackgroundColor: Colors.grey[50],

      // Card theme
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(8),
      ),

      // Button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          side: BorderSide(width: 1.0, color: Colors.white),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      // Text theme
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Colors.grey[800], fontSize: 16),
        bodyMedium: TextStyle(color: Colors.grey[700], fontSize: 14),
        titleLarge: TextStyle(
          color: Colors.grey[900],
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: Colors.grey[800],
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Slider theme
      sliderTheme: SliderThemeData(
        activeTrackColor: Colors.blue,
        inactiveTrackColor: Colors.blue.withOpacity(0.3),
        thumbColor: Colors.blue,
        overlayColor: Colors.blue.withOpacity(0.2),
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
      ),

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.blueGrey[800],
        contentTextStyle: TextStyle(color: Colors.white),
        actionTextColor: Colors.yellowAccent,
      ),
    );
  }

  ThemeData _buildContrastTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.yellow,
      primaryColor: Colors.yellow,
      scaffoldBackgroundColor: Colors.black,

      // Card theme
      cardTheme: CardThemeData(
        color: Colors.grey[700],
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: Colors.white, width: 2),
        ),
        margin: EdgeInsets.all(4),
      ),

      iconTheme: IconThemeData(color: Colors.white),

      // Button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          side: BorderSide(width: 1.0, color: Colors.black),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: Colors.white, width: 2),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),

      // Text theme
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        bodyMedium: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        titleLarge: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Slider theme
      sliderTheme: SliderThemeData(
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white.withOpacity(0.3),
        thumbColor: Colors.white,
        overlayColor: Colors.white.withOpacity(0.2),
        trackHeight: 6,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 16),
      ),

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        shape: Border(bottom: BorderSide(color: Colors.white, width: 2)),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.black87,
        contentTextStyle: TextStyle(color: Colors.white),
        actionTextColor: Colors.yellowAccent,
      ),
    );
  }
}

class SmartHomeScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChange;

  const SmartHomeScreen({Key? key, required this.onThemeChange})
    : super(key: key);

  @override
  _SmartHomeScreenState createState() => _SmartHomeScreenState();
}

class _SmartHomeScreenState extends State<SmartHomeScreen> {
  late final AdaptiveUIAdapter adapter;

  // Accessibility and UI preferences
  Map<String, double> buttonScales = {'lamp': 1.0, 'lock': 1.0};
  Map<String, double> fontSizes = {
    'lamp': 16.0,
    'thermostat': 16.0,
    'lock': 16.0,
    'title': 20.0,
    'welcome': 20.0,
  };
  Map<String, double> sliderSizes = {'thermostat': 1.0};
  Map<String, double> elementBorders = {'lamp': 1.0, 'lock': 1.0};
  Map<String, Offset> elementPositions = {
    'lamp': Offset.zero,
    'thermostat': Offset.zero,
    'lock': Offset.zero,
  };
  Map<String, double> elementSpacing = {
    'lamp': 8.0,
    'thermostat': 8.0,
    'lock': 8.0,
  };
  // Layout simplification
  bool simplifiedLayout = false;

  Map<String, String> deviceStatuses = {
    'lamp': 'Off',
    'thermostat': '20°C',
    'lock': 'Locked',
  };
  double thermostatValue = 20.0;
  String userId = 'user_133';
  bool isLoading = false;
  String? _loadingDevice;

  @override
  void initState() {
    super.initState();
    adapter = AdaptiveUIAdapter(userId, onAdaptations: applyAdaptations);
    adapter.checkProfile().then((exists) {
      if (!exists) {
        adapter.createProfile(
          UserProfile(
            userId: userId,
            accessibilityNeeds: {
              'motor_impaired': false,
              'visual_impaired': true,
              'hands_free_preferred': false,
            },
            inputPreferences: {'preferred_modality': 'voice'},
            uiPreferences: {
              'font_size': 16,
              'contrast_mode': 'normal',
              'button_size': 1.0,
            },
            interactionHistory: [],
          ),
        );
      }
    });
  }

  _switchToHighContrastTheme() {
    widget.onThemeChange(ThemeMode.dark);
  }

  _switchToNormalTheme() {
    widget.onThemeChange(ThemeMode.light);
  }

  void applyAdaptations(List<UIAdaptation> adaptations) {
    setState(() {
      isLoading = false;
      _loadingDevice = null;
    });

    List<String> appliedAdaptations = [];

    for (var adapt in adaptations) {
      String target = adapt.target;
      String action = adapt.action;

      switch (action) {
        case 'increase_button_size':
          if (target == "all") {
            for (var device in buttonScales.keys) {
              buttonScales[device] = adapt.value ?? 1.0;
            }
            appliedAdaptations.add('Increased all button sizes');
          } else if (buttonScales.containsKey(target)) {
            buttonScales[target] = adapt.value!;
            appliedAdaptations.add('Increased button size for $target');
          }
          break;

        case 'highlight_border':
          if (target == "all") {
            for (var device in elementBorders.keys) {
              elementBorders[device] = 2.0;
            }
            appliedAdaptations.add('Highlighted borders for all elements');
          } else {
            elementBorders[target] = 2.0;
            appliedAdaptations.add('Highlighted border for $target');
          }
          break;

        case 'increase_slider_size':
          if (target == "all") {
            for (var device in sliderSizes.keys) {
              sliderSizes[device] = adapt.value ?? 1.0;
            }
            appliedAdaptations.add('Increased all slider sizes');
          } else {
            sliderSizes[target] = adapt.value ?? 1.0;
            appliedAdaptations.add('Increased slider size for $target');
          }
          break;

        case 'increase_font_size':
          for (var key in fontSizes.keys) {
            fontSizes[key] = ((adapt.value ?? 1.2) * fontSizes[key]!);
          }
          appliedAdaptations.add('Increased font size');
          break;

        case 'increase_contrast':
          setState(() {
            _switchToHighContrastTheme();
          });
          appliedAdaptations.add('Switched to high contrast theme');
          break;

        case 'element_position':
          if (target == "all") {
            for (var device in elementPositions.keys) {
              elementPositions[device] = adapt.value ?? Offset.zero;
            }
            appliedAdaptations.add('Reset positions for all elements');
          } else {
            elementPositions[target] = adapt.value ?? Offset.zero;
            appliedAdaptations.add('Reset position for $target');
          }
          break;

        case 'adjust_spacing':
          if (target == "all") {
            for (var device in elementSpacing.keys) {
              elementSpacing[device] =
                  adapt.value != null
                      ? elementSpacing[device]! * adapt.value!
                      : 16.0;
            }
            appliedAdaptations.add('Adjusted spacing for all elements');
          } else {
            elementSpacing[target] =
                adapt.value != null
                    ? elementSpacing[target]! * adapt.value!
                    : 16.0;
            appliedAdaptations.add('Adjusted spacing for $target');
          }
          break;

        case 'show_tooltip':
          // Show tooltip for the specific element
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                adapt.value ?? 'Here is a helpful tip for $target!',
                style: TextStyle(fontSize: 16),
              ),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
          appliedAdaptations.add('Showed tooltip for $target');
          break;

        case 'switch_mode':
          if (adapt.mode != null) {
            // uiModes[target] = adapt.mode!;
            appliedAdaptations.add(
              'Switched UI navigation mode to ${adapt.mode}',
            );
          }
          break;

        case 'trigger_button':
          if (target == 'lamp') {
            deviceStatuses['lamp'] =
                deviceStatuses['lamp'] == 'On' ? 'Off' : 'On';
            appliedAdaptations.add('Toggled lamp');
          } else if (target == 'lock') {
            deviceStatuses['lock'] =
                deviceStatuses['lock'] == 'Locked' ? 'Unlocked' : 'Locked';
            appliedAdaptations.add('Toggled lock');
          }
          break;

        case 'simplify_layout':
          setState(() {
            simplifiedLayout = true;
          });
          appliedAdaptations.add('Simplified layout');
          break;
      }
    }

    // print('Applied adaptations: $appliedAdaptations');
    if (appliedAdaptations.isNotEmpty) {
      _showAdaptationSnackBar(appliedAdaptations);
    }
  }

  void _showAdaptationSnackBar(List<String> adaptations) {
    final adaptationText = adaptations.join(' • ');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: Colors.grey[400],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Applied: $adaptationText',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          bottom: MediaQuery.of(context).size.height - 115,
          left: 20,
          right: 20,
        ),
        duration: Duration(seconds: 3),

        // Show at the top
        // This is supported in Flutter 3.7+ with SnackBarActionLocation
        // But for now, using margin and floating behavior is the best way
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: buildAdaptiveText('Smart Home Controller', 'title'),
      ),
      backgroundColor: simplifiedLayout ? Colors.white : null,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(simplifiedLayout ? 8.0 : 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 35),
              buildAdaptiveText('Welcome, $userId!', 'welcome'),
              SizedBox(height: simplifiedLayout ? 8 : 16),
              if (simplifiedLayout)
                buildSimplifiedLayout()
              else
                buildStandardLayout(),
              SizedBox(height: 20),
              buildResetButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildAdaptiveText(String text, String target) {
    return Transform.translate(
      offset: elementPositions[target] ?? Offset.zero,
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSizes[target] ?? 16.0,
          fontWeight:
              target == 'title' || target == 'welcome'
                  ? FontWeight.bold
                  : FontWeight.normal,
        ),
      ),
    );
  }

  Widget buildSimplifiedLayout() {
    return Column(
      children: [
        buildDeviceCardWithLoadingIndicator('lamp', 'Lamp', ['On/Off']),
        buildDeviceCardWithLoadingIndicator('thermostat', 'Temperature', []),
        buildDeviceCardWithLoadingIndicator('lock', 'Lock', ['Toggle']),
      ],
    );
  }

  Widget buildStandardLayout() {
    return ListView(
      shrinkWrap: true,
      children: [
        buildDeviceCardWithLoadingIndicator('lamp', 'Living Room Lamp', [
          'On/Off',
        ]),
        buildDeviceCardWithLoadingIndicator('thermostat', 'Thermostat', []),
        buildDeviceCardWithLoadingIndicator('lock', 'Front Door Lock', [
          'Toggle',
        ]),
      ],
    );
  }

  Widget buildDeviceCardWithLoadingIndicator(
    String device,
    String title,
    List<String> actions,
  ) {
    bool isThisCardLoading = isLoading && _loadingDevice == device;

    final cardContent = Card(
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Transform.translate(
        offset: elementPositions[device] ?? Offset.zero,
        child: Padding(
          padding: EdgeInsets.only(
            top: simplifiedLayout ? 8 : 16,
            bottom: elementSpacing[device] ?? 8.0,
            left: simplifiedLayout ? 8 : 16,
            right: simplifiedLayout ? 8 : 16,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!simplifiedLayout)
                Icon(
                  device == 'lamp'
                      ? Icons.lightbulb
                      : device == 'thermostat'
                      ? Icons.thermostat
                      : Icons.lock,
                  size: 40 * (buttonScales[device] ?? 1.0),
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : device == 'lamp'
                          ? Colors.yellow[700]
                          : device == 'thermostat'
                          ? Colors.blue[700]
                          : Colors.grey[700],
                ),
              if (!simplifiedLayout) SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildAdaptiveText(title, device),
                    SizedBox(height: 8),
                    buildAdaptiveText(
                      'Status: ${deviceStatuses[device]}',
                      device,
                    ),
                    SizedBox(height: 8),
                    if (actions.isEmpty)
                      buildAdaptiveSlider(device)
                    else
                      ...buildActionButtons(device, actions),
                    if (!simplifiedLayout) ...[
                      SizedBox(height: 20),
                      Text("Mock Events:", style: TextStyle(fontSize: 16)),
                      SizedBox(height: 8),
                      buildMockButtons(device),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      margin: EdgeInsets.all(simplifiedLayout ? 4 : 8),
      decoration: BoxDecoration(
        boxShadow:
            isThisCardLoading && !simplifiedLayout
                ? [
                  BoxShadow(
                    color: Color(0xFFBC82F3).withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
                : null,
      ),
      child:
          simplifiedLayout
              ? cardContent
              : _AnimatedGlowBorder(
                animate: isThisCardLoading,
                child: cardContent,
              ),
    );
  }

  Widget buildAdaptiveSlider(String device) {
    return
    // scale: sliderSizes[device] ?? 1.0,
    SliderTheme(
      data: SliderTheme.of(context).copyWith(
        tickMarkShape: RoundSliderTickMarkShape(
          tickMarkRadius: 1.5 * (sliderSizes[device] ?? 1.0),
        ),
        thumbShape: RoundSliderThumbShape(
          enabledThumbRadius: 12 * (sliderSizes[device] ?? 1.0),
        ),
        trackHeight: 4 * (sliderSizes[device] ?? 1.0),
      ),
      child: Slider(
        value: thermostatValue,
        min: 0,
        max: 30,
        divisions: 30,
        label: thermostatValue.round().toString(),
        onChanged: (value) {
          setState(() {
            thermostatValue = value;
            deviceStatuses[device] = '${value.round()}°C';
          });
        },
      ),
    );
  }

  List<Widget> buildActionButtons(String device, List<String> actions) {
    return actions.map((action) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Transform.scale(
          scale: buttonScales[device] ?? 1.0,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom().copyWith(
              side: WidgetStateProperty.all(
                BorderSide(
                  width: elementBorders[device] ?? 1.0,
                  color:
                      Theme.of(
                        context,
                      ).elevatedButtonTheme.style?.side?.resolve({})?.color ??
                      Colors.transparent,
                ),
              ),
            ),
            onPressed: () {
              setState(() {
                deviceStatuses[device] =
                    (action == 'On/Off'
                        ? (deviceStatuses[device] == 'On' ? 'Off' : 'On')
                        : action == 'Toggle'
                        ? (deviceStatuses[device] == 'Locked'
                            ? 'Unlocked'
                            : 'Locked')
                        : deviceStatuses[device])!;
              });
            },
            child: Text(
              action,
              style: TextStyle(fontSize: (fontSizes[device] ?? 16.0) * 0.9),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget buildMockButtons(String device) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _loadingDevice = device;
                isLoading = true;
              });
              if (device == 'thermostat') {
                adapter.sendEvent(
                  Event(
                    eventType: 'slider_miss',
                    source: 'touch',
                    targetElement: device,
                    metadata: {'UI_element': 'slider'},
                  ),
                );
              } else {
                adapter.sendEvent(
                  Event(
                    eventType: 'miss_tap',
                    source: 'touch',
                    targetElement: device,
                    metadata: {'UI_element': 'button'},
                  ),
                );
              }
            },
            icon: Icon(Icons.touch_app),
            label: Text('Miss Tap'),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _loadingDevice = device;
                isLoading = true;
              });
              adapter.sendEvent(
                Event(
                  eventType: 'voice',
                  source: 'voice',
                  targetElement: device,
                  metadata: {
                    'command':
                        device == 'lamp'
                            ? 'turn_on'
                            : device == 'lock'
                            ? 'unlock'
                            : 'adjust',
                    'UI_element': device == 'thermostat' ? 'slider' : 'button',
                  },
                ),
              );
            },
            icon: Icon(Icons.mic),
            label: Text('Voice'),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _loadingDevice = device;
                isLoading = true;
              });
              adapter.sendEvent(
                Event(
                  eventType: 'gesture',
                  source: 'gesture',
                  targetElement: device,
                  metadata: {
                    'gesture_type': 'point',
                    'UI_element': device == 'thermostat' ? 'slider' : 'button',
                  },
                ),
              );
            },
            icon: Icon(Icons.gesture),
            label: Text('Gesture'),
          ),
        ),
      ],
    );
  }

  Widget buildResetButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() {
            // Reset all adaptations
            buttonScales = {'lamp': 1.0, 'thermostat': 1.0, 'lock': 1.0};
            fontSizes = {
              'lamp': 16.0,
              'thermostat': 16.0,
              'lock': 16.0,
              'title': 20.0,
              'welcome': 20.0,
            };
            sliderSizes = {'thermostat': 1.0};
            elementPositions = {
              'lamp': Offset.zero,
              'thermostat': Offset.zero,
              'lock': Offset.zero,
            };
            _switchToNormalTheme();
            simplifiedLayout = false;
            deviceStatuses = {
              'lamp': 'Off',
              'thermostat': '20°C',
              'lock': 'Locked',
            };
            thermostatValue = 20.0;
            elementBorders = {'lamp': 1.0, 'lock': 1.0};
            elementSpacing = {'lamp': 8.0, 'thermostat': 8.0, 'lock': 8.0};
            isLoading = false;
            _loadingDevice = null;
          });
        },
        icon: Icon(Icons.refresh),
        label: Text('Reset UI'),
      ),
    );
  }
}

class _AnimatedGlowBorder extends StatefulWidget {
  final Widget child;
  final bool animate;

  const _AnimatedGlowBorder({required this.child, required this.animate});

  @override
  _AnimatedGlowBorderState createState() => _AnimatedGlowBorderState();
}

class _AnimatedGlowBorderState extends State<_AnimatedGlowBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: SweepGradient(
              colors: const [
                Color(0xFFBC82F3),
                Color(0xFFF5B9EA),
                Color(0xFF8D9FFF),
                Color(0xFFAA6EEE),
                Color(0xFFFF6778),
                Color(0xFFFFBA71),
                Color(0xFFC686FF),
                Color(0xFFBC82F3),
              ],
              stops: const [0.0, 0.14, 0.29, 0.43, 0.57, 0.71, 0.86, 1.0],
              transform: GradientRotation(_controller.value * 2 * math.pi),
            ),
          ),
          child: Padding(padding: const EdgeInsets.all(2.0), child: child!),
        );
      },
    );
  }
}
