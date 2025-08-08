import 'dart:math' as math;
import 'adaptive_ui_adapter.dart';
import 'package:flutter/material.dart';

void main() => runApp(AdaptiveSmartHomeApp());

class AdaptiveSmartHomeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: SmartHomeScreen());
  }
}

class SmartHomeScreen extends StatefulWidget {
  @override
  _SmartHomeScreenState createState() => _SmartHomeScreenState();
}

class _SmartHomeScreenState extends State<SmartHomeScreen> {
  late final AdaptiveUIAdapter adapter;

  // Size adaptations
  Map<String, double> buttonScales = {
    'lamp': 1.0,
    'thermostat': 1.0,
    'lock': 1.0,
  };
  Map<String, double> fontSizes = {
    'lamp': 16.0,
    'thermostat': 16.0,
    'lock': 16.0,
    'title': 20.0,
    'welcome': 20.0,
  };
  Map<String, double> sliderSizes = {'thermostat': 1.0};

  // Position adaptations
  Map<String, Offset> elementPositions = {
    'lamp': Offset.zero,
    'thermostat': Offset.zero,
    'lock': Offset.zero,
  };

  // Contrast adaptations
  Map<String, String> contrastModes = {
    'lamp': 'normal',
    'thermostat': 'normal',
    'lock': 'normal',
    'title': 'normal',
    'welcome': 'normal',
  };

  // Mode switching
  Map<String, String> uiModes = {
    'lamp': 'standard',
    'thermostat': 'standard',
    'lock': 'standard',
  };

  // Layout simplification
  bool simplifiedLayout = false;

  Map<String, String> deviceStatuses = {
    'lamp': 'Off',
    'thermostat': '20°C',
    'lock': 'Locked',
  };
  double thermostatValue = 20.0;
  String userId = 'user_123';
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
              'motor_impaired': true,
              'visual_impaired': false,
              'hands_free_preferred': true,
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

  void applyAdaptations(List<UIAdaptation> adaptations) {
    setState(() {
      isLoading = false;
      _loadingDevice = null;
    });

    for (var adapt in adaptations) {
      String target = adapt.target;
      String action = adapt.action;

      switch (action) {
        case 'increase_size':
          if (adapt.value != null) {
            if (target.contains('button') ||
                ['lamp', 'thermostat', 'lock'].contains(target)) {
              buttonScales[target] = adapt.value!;
            } else if (target.contains('text') ||
                target.contains('title') ||
                target.contains('welcome')) {
              fontSizes[target] = adapt.value!;
            } else if (target.contains('slider')) {
              sliderSizes[target] = adapt.value!;
            }
          }
          break;

        // case 'reposition_element':
        //   if (adapt.position != null) {
        //     elementPositions[target] = adapt.position!;
        //   }
        //   break;

        case 'increase_contrast':
          if (adapt.mode != null) {
            contrastModes[target] = adapt.mode!;
          }
          break;

        case 'switch_mode':
          if (adapt.mode != null) {
            uiModes[target] = adapt.mode!;
          }
          break;

        case 'trigger_button':
          if (target == 'lamp') {
            deviceStatuses['lamp'] =
                deviceStatuses['lamp'] == 'On' ? 'Off' : 'On';
          } else if (target == 'lock') {
            deviceStatuses['lock'] =
                deviceStatuses['lock'] == 'Locked' ? 'Unlocked' : 'Locked';
          }
          break;

        case 'simplify_layout':
          simplifiedLayout = adapt.value == 1.0;
          break;
      }
    }
  }

  // Color helpers based on contrast mode
  Color getButtonColor(String target) {
    switch (contrastModes[target]) {
      case 'high':
        return Colors.black;
      case 'inverted':
        return Colors.white;
      default:
        return Colors.blue;
    }
  }

  Color getTextColor(String target) {
    switch (contrastModes[target]) {
      case 'high':
        return Colors.black;
      case 'inverted':
        return Colors.white;
      default:
        return Colors.grey[800]!;
    }
  }

  Color getBackgroundColor(String target) {
    switch (contrastModes[target]) {
      case 'high':
        return Colors.white;
      case 'inverted':
        return Colors.black;
      default:
        return Colors.grey[200]!;
    }
  }

  Color getSliderColor(String target) {
    switch (contrastModes[target]) {
      case 'high':
        return Colors.black;
      case 'inverted':
        return Colors.white;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: buildAdaptiveText('Smart Home Controller', 'title'),
        backgroundColor: getBackgroundColor('title'),
      ),
      backgroundColor: simplifiedLayout ? Colors.white : null,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(simplifiedLayout ? 8.0 : 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
          color: getTextColor(target),
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
    String mode = uiModes[device] ?? 'standard';

    final cardContent = Card(
      elevation: mode == 'minimal' ? 0 : 4,
      margin: EdgeInsets.zero,
      color: getBackgroundColor(device),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(mode == 'minimal' ? 4 : 10),
        side:
            contrastModes[device] == 'high'
                ? BorderSide(color: Colors.black, width: 2)
                : BorderSide.none,
      ),
      child: Transform.translate(
        offset: elementPositions[device] ?? Offset.zero,
        child: Padding(
          padding: EdgeInsets.all(simplifiedLayout ? 8 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildAdaptiveText(title, device),
              SizedBox(height: 8),
              buildAdaptiveText('Status: ${deviceStatuses[device]}', device),
              SizedBox(height: 8),
              if (actions.isEmpty)
                buildAdaptiveSlider(device)
              else
                ...buildActionButtons(device, actions),
              if (!simplifiedLayout) ...[
                SizedBox(height: 8),
                buildVoiceAndGestureButtons(device),
              ],
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
    return Transform.scale(
      scale: sliderSizes[device] ?? 1.0,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
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
          activeColor: getSliderColor(device),
          inactiveColor: getSliderColor(device).withOpacity(0.3),
          onChanged: (value) {
            setState(() {
              thermostatValue = value;
              deviceStatuses[device] = '${value.round()}°C';
            });
          },
        ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: getButtonColor(device),
              foregroundColor:
                  contrastModes[device] == 'inverted'
                      ? Colors.black
                      : Colors.white,
              minimumSize: Size(
                (uiModes[device] == 'large') ? 120 : 80,
                (uiModes[device] == 'large') ? 50 : 40,
              ),
            ),
            onPressed: () {
              setState(() {
                _loadingDevice = device;
                isLoading = true;
              });
              adapter.sendEvent(
                Event(eventType: 'tap', source: 'touch', targetElement: device),
              );
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

  Widget buildVoiceAndGestureButtons(String device) {
    return Row(
      children: [
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
                  },
                ),
              );
            },
            icon: Icon(Icons.mic),
            label: Text('Voice'),
            style: ElevatedButton.styleFrom(
              backgroundColor: getButtonColor(device).withOpacity(0.8),
            ),
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
                  metadata: {'gesture_type': 'point'},
                ),
              );
            },
            icon: Icon(Icons.touch_app),
            label: Text('Gesture'),
            style: ElevatedButton.styleFrom(
              backgroundColor: getButtonColor(device).withOpacity(0.6),
            ),
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
            contrastModes = {
              'lamp': 'normal',
              'thermostat': 'normal',
              'lock': 'normal',
              'title': 'normal',
              'welcome': 'normal',
            };
            uiModes = {
              'lamp': 'standard',
              'thermostat': 'standard',
              'lock': 'standard',
            };
            simplifiedLayout = false;
            deviceStatuses = {
              'lamp': 'Off',
              'thermostat': '20°C',
              'lock': 'Locked',
            };
            isLoading = false;
            _loadingDevice = null;
          });
        },
        icon: Icon(Icons.refresh),
        label: Text('Reset UI'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
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
