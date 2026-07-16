import Foundation
@testable import Portal

@available(macOS 12.0, iOS 15.0, *)
final class MockTransport: HTTPTransport {
    var result: Result<(Data, Int, [Header]), Error> = .success((Data(), 200, []))
    var resultProvider: (() -> Result<(Data, Int, [Header]), Error>)?
    var lastRequest: PortalRequest?

    func execute(_ request: PortalRequest) async throws -> (Data, Int, [Header]) {
        lastRequest = request
        return try (resultProvider?() ?? result).get()
    }
}
