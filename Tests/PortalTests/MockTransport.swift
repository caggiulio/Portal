import Foundation
@testable import Portal

@available(macOS 12.0, iOS 15.0, *)
final class MockTransport: HTTPTransport {
    var result: Result<(Data, Int), Error> = .success((Data(), 200))
    var lastRequest: PortalRequest?

    func execute(_ request: PortalRequest) async throws -> (Data, Int) {
        lastRequest = request
        return try result.get()
    }
}
