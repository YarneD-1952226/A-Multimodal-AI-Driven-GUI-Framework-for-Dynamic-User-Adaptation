// ------------------------------------------------------------
// File: AdaptiveUIApp.swift
// Tiny SwiftUI demo app applying a few core adaptations (KISS)

import SwiftUI

@main
struct AdaptiveUIApp: App {
    @StateObject private var adapter = AdaptiveUIAdapter(userId: "user_123")

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(adapter)
        }
    }
}

#if os(iOS)
import UIKit
public typealias EZColor    = UIColor
#elseif os(macOS)
import AppKit
public typealias EZColor    = NSColor
#endif


public extension EZColor {
    #if os(macOS)
    static var label: EZColor {
        return EZColor.labelColor
    }

    static var systemFill: EZColor {
        return NSColor.windowBackgroundColor // works for label, but it's a patch
        //return NSColor.controlColor // works, better for controls, but it's a patch
    }
    #endif
}


public extension Color {
    static var systemFill: Color {
        return Color(EZColor.systemFill)
    }
}

struct ContentView: View {
    @EnvironmentObject var adapter: AdaptiveUIAdapter

    @State private var lampOn = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var borderWidth: CGFloat = 0
    @State private var highContrast = false
    @State private var fontScale: CGFloat = 1.0
    @State private var spacing: CGFloat = 12
    @State private var tooltip: String?

    var body: some View {
        let fg = highContrast ? Color.white : Color.primary
        let bg = highContrast ? Color.black : Color.systemFill

        VStack(spacing: spacing) {
            Text("Adaptive Smart Home Controller")
                .font(.system(size: 18 * fontScale, weight: .semibold))
                .padding(.top)

            LampCard(lampOn: $lampOn,
                     buttonScale: buttonScale,
                     borderWidth: borderWidth,
                     fg: fg, bg: bg,
                     tooltip: $tooltip,
                     onTap: sendTap,
                     onMissTap: sendMissTap,
                     onVoice: sendVoice)
                .padding()
                .background(bg)
                .cornerRadius(16)
                .shadow(radius: 4)

            Button("Reset UI", role: .destructive) { resetUI() }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 8)

            if let tip = tooltip {
                Text(tip)
                    .font(.system(size: 14 * fontScale))
                    .padding(8)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(8)
            }

            List(adapter.lastAdaptations) { a in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(a.action) → \(a.target)")
                        .font(.system(size: 14))
                    Text(a.reason).font(.footnote).foregroundColor(.secondary)
                }
            }
            .frame(maxHeight: 180)
        }
        .padding()
        .preferredColorScheme(highContrast ? .dark : nil)
        .onAppear { adapter.onAdaptations = { apply($0) } }
    }

    // MARK: - Send example events
    func sendTap() {
//        let event = Event(
//            eventType: "tap",
//            source: "touch",
//            timestamp: ISO8601DateFormatter().string(from: Date()),
//            userId: "user_123",
//            targetElement: "button_lamp",
//            coordinates: nil,
//            confidence: 1.0,
//            metadata: nil
//        )
//        adapter.sendEvent(event)
        lampOn = !lampOn
    }

    func sendMissTap() {
        let event = Event(
            eventType: "miss_tap",
            source: "touch",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            userId: "user_123",
            targetElement: "button_lamp",
            coordinates: Event.Coordinates(x: 10, y: 10),
            confidence: 0.8,
            metadata: nil
        )
        adapter.sendEvent(event)
    }

    func sendVoice() {
        let event = Event(
            eventType: "voice",
            source: "voice",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            userId: "user_123",
            targetElement: "button_lamp",
            coordinates: nil,
            confidence: 0.9,
            metadata: ["command": "turn on"]
        )
        adapter.sendEvent(event)
    }
    func resetUI() {
        lampOn = false
        buttonScale = 1.0
        borderWidth = 0
        highContrast = false
        fontScale = 1.0
        spacing = 12
        tooltip = nil
        adapter.lastAdaptations = []
    }

    // MARK: - Apply basic adaptations
    func apply(_ adaptations: [Adaptation]) {
        for a in adaptations {
            switch a.action {
            case "increase_button_size":
                if a.target == "button_lamp" || a.target == "all" {
                    let v = CGFloat(a.value ?? 1.2)
                    buttonScale *= max(0.5, min(v, 2.5))
                }
            case "increase_font_size":
                let v = CGFloat(a.value ?? 1.1)
                fontScale *= max(0.8, min(v, 2.0))
            case "increase_contrast":
                highContrast = (a.mode == "high") || (a.mode == nil)
            case "increase_button_border":
                borderWidth = 2
            case "adjust_spacing":
                let v = CGFloat(a.value ?? 1.2)
                spacing = max(8, min(24, spacing * v))
            case "show_tooltip":
                tooltip = a.reason
            case "trigger_button":
                if a.target == "button_lamp" { lampOn.toggle() }
            default:
                break
            }
        }
    }
}

struct LampCard: View {
    @Binding var lampOn: Bool
    var buttonScale: CGFloat
    var borderWidth: CGFloat
    var fg: Color
    var bg: Color
    @Binding var tooltip: String?

    var onTap: () -> Void
    var onMissTap: () -> Void
    var onVoice: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Living Room Lamp")
                .foregroundColor(fg)

            Button(action: onTap) {
                Text(lampOn ? "On" : "Off")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(lampOn ? Color.green : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .scaleEffect(buttonScale)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: borderWidth))

            HStack {
                Button("Miss‑tap") { onMissTap() }
                Button("Voice: “turn on”") { onVoice() }
                Button("Clear Tip") { tooltip = nil }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
