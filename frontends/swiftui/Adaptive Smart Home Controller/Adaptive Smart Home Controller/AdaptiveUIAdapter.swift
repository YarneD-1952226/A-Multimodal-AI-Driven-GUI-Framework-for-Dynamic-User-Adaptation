// File: AdaptiveUIAdapter.swift
// Minimal adapter for Smart Intent Fusion (FastAPI backend)
// iOS 15+, Swift 5.7+. For local dev over HTTP/WS you may need ATS exceptions in Info.plist.

import Foundation
import Combine

struct Event: Codable {
    let eventType: String
    let source: String
    let timestamp: String
    let userId: String
    let targetElement: String?
    let coordinates: Coordinates?
    let confidence: Double?
    let metadata: [String: String]?

    struct Coordinates: Codable { let x: Double; let y: Double }

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case source
        case timestamp
        case userId = "user_id"
        case targetElement = "target_element"
        case coordinates
        case confidence
        case metadata
    }
}

struct Adaptation: Codable, Identifiable {
    var id: UUID { UUID() }
    let action: String
    let target: String
    let value: Double?
    let mode: String?
    let reason: String
    let intent: String
}

final class AdaptiveUIAdapter: ObservableObject {
    @Published var lastAdaptations: [Adaptation] = []

    private let httpBase: URL
    private let wsURL: URL
    private let userId: String
    private var task: URLSessionWebSocketTask?
    private var session: URLSession

    var onAdaptations: (([Adaptation]) -> Void)?

    init(httpBase: URL = URL(string: "http://127.0.0.1:8000")!,
         wsURL: URL = URL(string: "ws://127.0.0.1:8000/ws/adapt")!,
         userId: String) {
        self.httpBase = httpBase
        self.wsURL = wsURL
        self.userId = userId
        self.session = URLSession(configuration: .default)
        Task {
            await ensureProfileExists()
            connect()
        }
    }

    func connect() {
        task?.cancel()
        task = session.webSocketTask(with: wsURL)
        task?.resume()
        listen()
    }

    func disconnect() { task?.cancel(with: .goingAway, reason: nil); task = nil }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                print("WS receive error: \(error.localizedDescription)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.connect() }
            case .success(let message):
                var data: Data?
                switch message {
                case .data(let d): data = d
                case .string(let s): data = s.data(using: .utf8)
                @unknown default: break
                }
                if let data = data { self.handleIncoming(data) }
                self.listen() // keep listening
            }
        }
    }

    private struct Envelope: Codable { let adaptations: [Adaptation] }

    private func handleIncoming(_ data: Data) {
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            DispatchQueue.main.async {
                self.lastAdaptations = envelope.adaptations
                self.onAdaptations?(envelope.adaptations)
            }
        } catch {
            print("Decode error: \(error)")
            if let s = String(data: data, encoding: .utf8) { print("Raw: \(s)") }
        }
    }

    func sendEvent(_ event: Event) {
        guard let task = task else { return }
        do {
            let enc = JSONEncoder()
            enc.keyEncodingStrategy = .convertToSnakeCase
            let payload = try enc.encode(event)
            if let json = String(data: payload, encoding: .utf8) {
                task.send(.string(json)) { error in
                    if let error = error { print("WS send error: \(error)") }
                }
            }
        } catch { print("Encode error: \(error)") }
    }

    // MARK: - Profile
    @MainActor
    func ensureProfileExists() async {
        let getURL = httpBase.appendingPathComponent("profile/\(userId)")
        var request = URLRequest(url: getURL)
        request.httpMethod = "GET"
        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 { return }
        } catch { /* 404 etc. create below */ }

        // Create a minimal default profile
        let postURL = httpBase.appendingPathComponent("profile")
        var postReq = URLRequest(url: postURL)
        postReq.httpMethod = "POST"
        postReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let profile: [String: Any] = [
            "user_id": userId,
            "accessibility_needs": [:],
            "input_preferences": [:],
            "ui_preferences": [:],
            "interaction_history": []
        ]
        do {
            postReq.httpBody = try JSONSerialization.data(withJSONObject: profile, options: [])
            let (_, response) = try await session.data(for: postReq)
            if let http = response as? HTTPURLResponse { print("Profile POST: \(http.statusCode)") }
        } catch { print("Profile create error: \(error)") }
    }
}
