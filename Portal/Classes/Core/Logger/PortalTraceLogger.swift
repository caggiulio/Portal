import Foundation

class PortalTraceLogger {
    var logLevel = PortalTraceLoggerLevel.debug

    func logRequest(_ request: PortalRequest) {
        guard logLevel != .none else { return }
        NSLog("\n⬆️ ----- START REQUEST ----- ⬆️")
        NSLog("    -- Url: \(request.path.url)")
        NSLog("    -- Method: \(request.method.rawValue)")
        if let headers = request.header, !headers.isEmpty {
            NSLog("    -- Headers:")
            headers.forEach { NSLog("        -- \($0.key): \($0.value)") }
        }
        NSLog("⬆️ ----- END REQUEST ----- ⬆️")
    }

    func logResponse(statusCode: Int, data: Data?, error: Error?) {
        guard logLevel != .none else { return }
        NSLog("\n⬇️ ----- START RESPONSE ----- ⬇️")
        if statusCode >= 200, statusCode < 300 {
            NSLog("    -- Status Code: ✅ \(statusCode)")
        } else {
            NSLog("    -- Status Code: ❌ \(statusCode)")
        }
        if logLevel == .debug {
            if let data, let body = String(data: data, encoding: .utf8) {
                NSLog("    -- Body: \(body)")
            }
            if let error {
                NSLog("    -- Error: 🚨 \(error.localizedDescription)")
            }
        }
        NSLog("⬇️ ----- END RESPONSE ----- ⬇️")
    }
}
