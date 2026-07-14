import Testing
import Foundation
@testable import Portal

@Suite("PortalError")
struct PortalErrorTests {
    @Test func invalidUrl() {
        let error = PortalError.invalidUrl
        if case .invalidUrl = error { } else { Issue.record("wrong case") }
    }

    @Test func invalidHTTPResponse() {
        let error = PortalError.invalidHTTPResponse
        if case .invalidHTTPResponse = error { } else { Issue.record("wrong case") }
    }

    @Test func decodingFailed() {
        struct FakeError: Error {}
        let error = PortalError.decodingFailed(error: FakeError())
        if case .decodingFailed = error { } else { Issue.record("wrong case") }
    }

    @Test func other() {
        struct FakeError: Error {}
        let error = PortalError.other(error: FakeError())
        if case .other = error { } else { Issue.record("wrong case") }
    }

    @Test func underlying() {
        let data = Data([0xFF])
        let error = PortalError.underlying(statusCode: 404, data: data)
        if case .underlying(let code, let d) = error {
            #expect(code == 404)
            #expect(d == data)
        } else { Issue.record("wrong case") }
    }

    @Test func underlyingNilData() {
        let error = PortalError.underlying(statusCode: 500, data: nil)
        if case .underlying(let code, let d) = error {
            #expect(code == 500)
            #expect(d == nil)
        } else { Issue.record("wrong case") }
    }
}
