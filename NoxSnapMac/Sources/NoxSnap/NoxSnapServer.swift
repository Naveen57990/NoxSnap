import AppKit
import Foundation
import Network

public final class NoxSnapServer: @unchecked Sendable {
    public static let shared = NoxSnapServer()
    
    public let port: UInt16 = 53320
    private var listener: NWListener?
    public private(set) var isRunning: Bool = false
    
    private var lastHandoffTime = Date.distantPast
    private var lastHandoffDirection: String = ""
    private let serverLock = NSLock()
    
    private init() {}
    
    public func start() {
        guard !isRunning else { return }
        
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            
            let hostName = Host.current().localizedName ?? "MacBook"
            listener?.service = NWListener.Service(name: hostName, type: "_noxsnap._tcp")
            
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isRunning = true
                    print("⚡️ NoxSnap Server ready on port \(self?.port ?? 0), Bonjour: _noxsnap._tcp")
                case .failed(let err):
                    print("❌ NoxSnap Server failed: \(err)")
                    self?.isRunning = false
                case .cancelled:
                    self?.isRunning = false
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            print("❌ Failed to start NoxSnap Server: \(error)")
        }
    }
    
    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }
            
            guard let requestStr = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            
            let lines = requestStr.components(separatedBy: "\r\n")
            guard let requestLine = lines.first else {
                connection.cancel()
                return
            }
            
            let parts = requestLine.components(separatedBy: " ")
            guard parts.count >= 2 else {
                connection.cancel()
                return
            }
            
            let method = parts[0].uppercased()
            let rawPath = parts[1]
            let pathUrl = URL(string: "http://localhost" + rawPath)
            let path = pathUrl?.path ?? rawPath
            
            var queryParams: [String: String] = [:]
            if let components = URLComponents(url: pathUrl ?? URL(string: "http://localhost")!, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems {
                for item in queryItems {
                    queryParams[item.name.lowercased()] = item.value ?? ""
                }
            }
            
            var headers: [String: String] = [:]
            for line in lines.dropFirst() {
                if line.isEmpty { break }
                let headerParts = line.split(separator: ":", maxSplits: 1)
                if headerParts.count == 2 {
                    let k = headerParts[0].trimmingCharacters(in: .whitespaces).lowercased()
                    let v = headerParts[1].trimmingCharacters(in: .whitespaces)
                    headers[k] = v
                }
            }
            
            // Extract HTTP Body if present
            var bodyJson: [String: Any]? = nil
            if let bodyRange = requestStr.range(of: "\r\n\r\n") {
                let bodyStr = String(requestStr[bodyRange.upperBound...])
                if let bodyData = bodyStr.data(using: .utf8), !bodyData.isEmpty {
                    bodyJson = (try? JSONSerialization.jsonObject(with: bodyData)) as? [String: Any]
                }
            }
            
            if method == "OPTIONS" {
                self.respondCORS(connection: connection)
                return
            }
            
            if path == "/open-panel" {
                DispatchQueue.main.async {
                    ControlWindowController.shared.show()
                }
                self.respondOK(connection: connection, json: ["status": "ok"])
                return
            }
            
            if path == "/test-notch" || path == "/test-repel" {
                let testDir = queryParams["direction"] ?? "push"
                DispatchQueue.main.async {
                    MagneticRepelOverlay.shared.triggerRepelEffect(direction: testDir, url: "https://apple.com")
                }
                self.respondOK(connection: connection, json: ["status": "ok", "effect": "magnetic-repel", "direction": testDir])
                return
            }
            
            if path == "/status" || path == "/health" {
                self.respondOK(connection: connection, json: [
                    "status": "online",
                    "appName": "NoxSnap",
                    "deviceName": Host.current().localizedName ?? "MacBook",
                    "version": "2.1"
                ])
                return
            }
            
            if path == "/dock" {
                let sideHeader = headers["x-dock-side"]?.lowercased()
                let sideQuery = queryParams["side"]?.lowercased()
                let sideBody = bodyJson?["side"] as? String
                let incomingSide = sideHeader ?? sideQuery ?? sideBody?.lowercased() ?? "right"
                
                // Read Mac user preference for ripple origin:
                // Options: "right" (default), "left", "both", "invert", "phone"
                let sidePref = UserDefaults.standard.string(forKey: "NoxSnapRippleSidePref") ?? "right"
                let side: String
                switch sidePref {
                case "right":
                    side = "right"
                case "left":
                    side = "left"
                case "both":
                    side = "both"
                case "invert":
                    side = (incomingSide == "left") ? "right" : "left"
                default: // "phone" / auto
                    side = incomingSide
                }
                
                self.serverLock.lock()
                let now = Date()
                let elapsed = now.timeIntervalSince(self.lastHandoffTime)
                if elapsed < 1.2 {
                    print("🛡️ Server Cooldown Gate: Dropped rapid repeat dock request within \(elapsed)s")
                    self.serverLock.unlock()
                    self.respondOK(connection: connection, json: [
                        "action": "push_to_mac",
                        "status": "cooldown_ignored"
                    ])
                    return
                }
                self.lastHandoffTime = now
                self.serverLock.unlock()
                
                let phoneUrl = headers["x-handoff-url"] ?? (bodyJson?["url"] as? String)
                let rawText = headers["x-handoff-text"] ?? (bodyJson?["text"] as? String)
                let phoneText = rawText?.removingPercentEncoding ?? rawText
                
                // Pure Phone ➔ Mac Push: Seamlessly open in active Chrome window
                if let rawUrl = phoneUrl?.removingPercentEncoding ?? phoneUrl, !rawUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    BrowserHandoffManager.shared.openURL(rawUrl, side: side)
                } else if let t = phoneText, !t.isEmpty {
                    BrowserHandoffManager.shared.copyToClipboard(t)
                }
                
                self.respondOK(connection: connection, json: [
                    "action": "push_to_mac",
                    "status": "opened_in_chrome",
                    "side": side,
                    "deviceName": Host.current().localizedName ?? "MacBook"
                ])
                return
            }
            
            self.respondNotFound(connection: connection)
        }
    }
    
    private func respondOK(connection: NWConnection, json: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []),
              let jsonStr = String(data: jsonData, encoding: .utf8) else {
            connection.cancel()
            return
        }
        
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json; charset=utf-8\r
        Access-Control-Allow-Origin: *\r
        Content-Length: \(jsonData.count)\r
        Connection: close\r
        \r
        \(jsonStr)
        """
        
        if let data = response.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed({ _ in
                connection.cancel()
            }))
        } else {
            connection.cancel()
        }
    }
    
    private func respondCORS(connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: GET, POST, OPTIONS\r
        Access-Control-Allow-Headers: *\r
        Content-Length: 0\r
        Connection: close\r
        \r
        """
        if let data = response.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed({ _ in
                connection.cancel()
            }))
        } else {
            connection.cancel()
        }
    }
    
    private func respondNotFound(connection: NWConnection) {
        let response = """
        HTTP/1.1 404 Not Found\r
        Content-Length: 0\r
        Connection: close\r
        \r
        """
        if let data = response.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed({ _ in
                connection.cancel()
            }))
        } else {
            connection.cancel()
        }
    }
}
