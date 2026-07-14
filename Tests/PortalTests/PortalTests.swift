import Testing
import Foundation
@testable import Portal

struct Response: Codable, Equatable { let id: Int }

func encoded<T: Encodable>(_ value: T) -> Data { try! JSONEncoder().encode(value) }

func makePortal(transport: MockTransport, interceptor: PortalInterceptorProtocol? = nil) -> Portal {
    Portal(baseURL: "https://api.example.com", transport: transport, interceptor: interceptor)
}

@Suite("Portal.send(request:)")
struct PortalSendTests {
    @Test func success() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 1)), 200))
        let response: Response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .get, path: Path(url: "/items", query: nil))
        )
        #expect(response.id == 1)
    }

    @Test func buildsFullURL() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 1)), 200))
        let _: Response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .get, path: Path(url: "/items", query: nil))
        )
        #expect(transport.lastRequest?.path.url.contains("api.example.com") == true)
    }

    @Test func decodingFailure() async throws {
        let transport = MockTransport()
        transport.result = .success(("invalid json".data(using: .utf8)!, 200))
        await #expect(throws: PortalError.self) {
            let _: Response = try await makePortal(transport: transport).send(
                request: PortalRequest(method: .get, path: Path(url: "/items", query: nil))
            )
        }
    }

    @Test func non2xxThrowsUnderlying() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 404))
        do {
            let _: Response = try await makePortal(transport: transport).send(
                request: PortalRequest(method: .get, path: Path(url: "/missing", query: nil))
            )
            Issue.record("expected throw")
        } catch let error as PortalError {
            if case .underlying(let code, _) = error { #expect(code == 404) }
            else { Issue.record("wrong error") }
        }
    }

    @Test func transportErrorPropagates() async throws {
        let transport = MockTransport()
        struct NetError: Error {}
        transport.result = .failure(NetError())
        await #expect(throws: (any Error).self) {
            let _: Response = try await makePortal(transport: transport).send(
                request: PortalRequest(method: .get, path: Path(url: "/fail", query: nil))
            )
        }
    }

    @Test func appliesHttpsScheme() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 99)), 200))
        let _: Response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .get, path: Path(url: "/secure", query: nil), scheme: .https)
        )
        #expect(transport.lastRequest?.path.url.hasPrefix("https://") == true)
    }

    @Test func nilSchemeNoOverride() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 2)), 200))
        let _: Response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .get, path: Path(url: "/api", query: nil), scheme: nil)
        )
        #expect(transport.lastRequest != nil)
    }

    @Test func queryParamsForwarded() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 4)), 200))
        let _: Response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .get, path: Path(url: "/list", query: [URLQueryItem(name: "page", value: "2")]))
        )
        #expect(transport.lastRequest?.path.query?.first?.name == "page")
    }

    @Test func applySchemeReplacesExistingScheme() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 3)), 200))
        let portal = Portal(baseURL: "http://api.example.com", transport: transport)
        let _: Response = try await portal.send(
            request: PortalRequest(method: .get, path: Path(url: "/x", query: nil), scheme: .https)
        )
        #expect(transport.lastRequest?.path.url.hasPrefix("https://") == true)
    }

    @Test func urlWithoutSchemeGetsSchemeApplied() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 3)), 200))
        let portal = Portal(baseURL: "api.example.com", transport: transport)
        let _: Response = try await portal.send(
            request: PortalRequest(method: .get, path: Path(url: "/path", query: nil), scheme: .https)
        )
        #expect(transport.lastRequest?.path.url.hasPrefix("https://") == true)
    }
}

@Suite("Portal interceptor")
struct PortalInterceptorTests {
    @Test func adaptIsCalled() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 5)), 200))

        final class HeaderInterceptor: PortalInterceptorProtocol {
            var adapted = false
            func adapt(_ request: PortalRequest) -> PortalRequest {
                adapted = true
                var r = request; r.header = ["X-Token": "abc"]; return r
            }
        }

        let interceptor = HeaderInterceptor()
        let _: Response = try await makePortal(transport: transport, interceptor: interceptor).send(
            request: PortalRequest(method: .get, path: Path(url: "/me", query: nil))
        )
        #expect(interceptor.adapted)
        #expect(transport.lastRequest?.header?["X-Token"] as? String == "abc")
    }

    @Test func doNotRetry() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 401))
        final class NoRetryInterceptor: PortalInterceptorProtocol {}
        await #expect(throws: (any Error).self) {
            let _: Response = try await makePortal(transport: transport, interceptor: NoRetryInterceptor()).send(
                request: PortalRequest(method: .get, path: Path(url: "/auth", query: nil))
            )
        }
    }

    @Test func retryOnceSucceeds() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 401))

        final class RetryOnceInterceptor: PortalInterceptorProtocol {
            var retried = false
            let transport: MockTransport
            let successData: Data
            init(transport: MockTransport, successData: Data) { self.transport = transport; self.successData = successData }
            func retry(_ request: PortalRequest, dueTo error: Error) async throws -> RetryResult {
                if !retried { retried = true; transport.result = .success((successData, 200)); return .retry }
                return .doNotRetry
            }
        }

        let successData = encoded(Response(id: 42))
        let interceptor = RetryOnceInterceptor(transport: transport, successData: successData)
        let response: Response = try await makePortal(transport: transport, interceptor: interceptor).send(
            request: PortalRequest(method: .get, path: Path(url: "/retry", query: nil))
        )
        #expect(response.id == 42)
    }
}

@Suite("Portal logLevel")
struct PortalLogLevelTests {
    @Test func getSet() {
        let transport = MockTransport()
        let portal = makePortal(transport: transport)
        portal.logLevel = .none
        #expect(portal.logLevel == .none)
        portal.logLevel = .release
        #expect(portal.logLevel == .release)
    }

    @Test func noneLogLevelStillExecutes() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 1)), 200))
        let portal = makePortal(transport: transport)
        portal.logLevel = .none
        let response: Response = try await portal.send(
            request: PortalRequest(method: .get, path: Path(url: "/ok", query: nil))
        )
        #expect(response.id == 1)
    }

    @Test func releaseLogLevelStillExecutes() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 2)), 200))
        let portal = makePortal(transport: transport)
        portal.logLevel = .release
        let response: Response = try await portal.send(
            request: PortalRequest(method: .get, path: Path(url: "/ok", query: nil))
        )
        #expect(response.id == 2)
    }

    @Test func releaseLogLevelOnError() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 500))
        let portal = makePortal(transport: transport)
        portal.logLevel = .release
        await #expect(throws: (any Error).self) {
            let _: Response = try await portal.send(
                request: PortalRequest(method: .get, path: Path(url: "/err", query: nil))
            )
        }
    }
}

@Suite("Portal cancellation")
struct PortalCancellationTests {
    @Test func sendThrowsWhenAlreadyCancelled() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 1)), 200))
        let portal = makePortal(transport: transport)
        let task = Task<Response, Error> {
            try await portal.send(request: PortalRequest(method: .get, path: Path(url: "/items", query: nil)))
        }
        task.cancel()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test func multipartSendThrowsWhenAlreadyCancelled() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 2)), 200))
        let portal = makePortal(transport: transport)
        let media = PortalMedia(data: Data([0x01]), key: "f", filename: "f.jpg", mimeType: "image/jpeg")
        let task = Task<Response, Error> {
            try await portal.send(
                request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
                medias: [media],
                boundary: "b"
            )
        }
        task.cancel()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}

@Suite("Portal.send(request:medias:boundary:)")
struct PortalMultipartTests {
    @Test func success() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 7)), 200))
        let media = PortalMedia(data: Data([0x01]), key: "file", filename: "img.jpg", mimeType: "image/jpeg")
        let response: Response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
            medias: [media],
            boundary: "boundary123"
        )
        #expect(response.id == 7)
    }

    @Test func setsContentTypeHeader() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 8)), 200))
        let media = PortalMedia(data: Data([0xFF]), key: "avatar", filename: "av.png", mimeType: "image/png")
        let _: Response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
            medias: [media],
            boundary: "myboundary"
        )
        let contentType = transport.lastRequest?.header?["Content-Type"] as? String
        #expect(contentType?.contains("multipart/form-data") == true)
        #expect(contentType?.contains("myboundary") == true)
    }

    @Test func withBodyParams() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 9)), 200))
        struct Params: Encodable { let name: String }
        let media = PortalMedia(data: Data([0xAB]), key: "doc", filename: "doc.pdf", mimeType: "application/pdf")
        let response: Response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil), body: Body(data: Params(name: "test"), encoding: .json)),
            medias: [media],
            boundary: "b42"
        )
        #expect(response.id == 9)
    }

    @Test func decodingFailure() async throws {
        let transport = MockTransport()
        transport.result = .success(("bad".data(using: .utf8)!, 200))
        let media = PortalMedia(data: Data([0x00]), key: "f", filename: "f.bin", mimeType: "application/octet-stream")
        await #expect(throws: PortalError.self) {
            let _: Response = try await makePortal(transport: transport).send(
                request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
                medias: [media],
                boundary: "b"
            )
        }
    }

    @Test func non2xxThrows() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 500))
        let media = PortalMedia(data: Data([0x00]), key: "f", filename: "f.bin", mimeType: "application/octet-stream")
        await #expect(throws: (any Error).self) {
            let _: Response = try await makePortal(transport: transport).send(
                request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
                medias: [media],
                boundary: "b"
            )
        }
    }

    @Test func interceptorAdapts() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 10)), 200))
        final class TokenInterceptor: PortalInterceptorProtocol {
            func adapt(_ request: PortalRequest) -> PortalRequest {
                var r = request
                r.header = (r.header ?? [:]).merging(["Authorization": "Bearer tok"]) { _, new in new }
                return r
            }
        }
        let media = PortalMedia(data: Data([0x01]), key: "img", filename: "i.jpg", mimeType: "image/jpeg")
        let response: Response = try await makePortal(transport: transport, interceptor: TokenInterceptor()).send(
            request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
            medias: [media],
            boundary: "b"
        )
        #expect(response.id == 10)
    }
}
