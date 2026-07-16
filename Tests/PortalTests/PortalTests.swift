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
        transport.result = .success((encoded(Response(id: 1)), 200, []))
        let response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .get, path: Path(url: "/items", query: nil)),
            decoding: Response.self
        )
        #expect(response.value.id == 1)
    }

    @Test func buildsFullURL() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 1)), 200, []))
        _ = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .get, path: Path(url: "/items", query: nil)),
            decoding: Response.self
        )
        #expect(transport.lastRequest?.path.url.contains("api.example.com") == true)
    }

    @Test func decodingFailure() async throws {
        let transport = MockTransport()
        transport.result = .success(("invalid json".data(using: .utf8)!, 200, []))
        await #expect(throws: PortalError.self) {
            _ = try await makePortal(transport: transport).send(
                request: PortalRequest(method: .get, path: Path(url: "/items", query: nil)),
                decoding: Response.self
            )
        }
    }

    @Test func non2xxThrowsUnderlying() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 404, []))
        do {
            _ = try await makePortal(transport: transport).send(
                request: PortalRequest(method: .get, path: Path(url: "/missing", query: nil)),
                decoding: Response.self
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
            _ = try await makePortal(transport: transport).send(
                request: PortalRequest(method: .get, path: Path(url: "/fail", query: nil)),
                decoding: Response.self
            )
        }
    }

    @Test func appliesHttpsScheme() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 99)), 200, []))
        _ = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .get, path: Path(url: "/secure", query: nil), scheme: .https),
            decoding: Response.self
        )
        #expect(transport.lastRequest?.path.url.hasPrefix("https://") == true)
    }

    @Test func nilSchemeNoOverride() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 2)), 200, []))
        _ = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .get, path: Path(url: "/api", query: nil), scheme: nil),
            decoding: Response.self
        )
        #expect(transport.lastRequest != nil)
    }

    @Test func queryParamsForwarded() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 4)), 200, []))
        _ = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .get, path: Path(url: "/list", query: [URLQueryItem(name: "page", value: "2")])),
            decoding: Response.self
        )
        #expect(transport.lastRequest?.path.query?.first?.name == "page")
    }

    @Test func applySchemeReplacesExistingScheme() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 3)), 200, []))
        let portal = Portal(baseURL: "http://api.example.com", transport: transport)
        _ = try await portal.send(
            request: PortalRequest(method: .get, path: Path(url: "/x", query: nil), scheme: .https),
            decoding: Response.self
        )
        #expect(transport.lastRequest?.path.url.hasPrefix("https://") == true)
    }

    @Test func urlWithoutSchemeGetsSchemeApplied() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 3)), 200, []))
        let portal = Portal(baseURL: "api.example.com", transport: transport)
        _ = try await portal.send(
            request: PortalRequest(method: .get, path: Path(url: "/path", query: nil), scheme: .https),
            decoding: Response.self
        )
        #expect(transport.lastRequest?.path.url.hasPrefix("https://") == true)
    }

    @Test func decodingWithExplicitType() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 42)), 200, []))
        let response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .get, path: Path(url: "/items", query: nil)),
            decoding: Response.self
        )
        #expect(response.value.id == 42)
    }

    @Test func responseContainsStatusCode() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 1)), 201, []))
        let response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .post, path: Path(url: "/items", query: nil)),
            decoding: Response.self
        )
        #expect(response.statusCode == 201)
    }

    @Test func responseContainsHeaders() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 1)), 200, [Header(key: "X-Request-ID", value: "abc")]))
        let response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .get, path: Path(url: "/items", query: nil)),
            decoding: Response.self
        )
        #expect(response.headers.first(where: { $0.key.rawValue == "X-Request-ID" })?.value.rawValue == "abc")
    }

    @Test func responseContainsRequest() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 1)), 200, []))
        let request = PortalRequest(method: .get, path: Path(url: "/items", query: nil))
        let response = try await makePortal(transport: transport).send(request: request, decoding: Response.self)
        #expect(response.request.path.url.contains("/items"))
    }

    @Test func responseContainsAllHeaders() async throws {
        let transport = MockTransport()
        let responseHeaders: [Header] = [
            Header(key: "X-Request-ID", value: "abc"),
            Header(key: "X-Rate-Limit", value: "100"),
            Header(key: "Content-Type", value: "application/json")
        ]
        transport.result = .success((encoded(Response(id: 1)), 200, responseHeaders))
        let response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .get, path: Path(url: "/items", query: nil)),
            decoding: Response.self
        )
        #expect(response.headers.count == 3)
        #expect(response.headers.first(where: { $0.key.rawValue == "X-Rate-Limit" })?.value.rawValue == "100")
    }
}

@Suite("Portal interceptor")
struct PortalInterceptorTests {
    @Test func adaptIsCalled() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 5)), 200, []))

        final class HeaderInterceptor: PortalInterceptorProtocol {
            var adapted = false
            func adapt(_ request: PortalRequest) -> PortalRequest {
                adapted = true
                var r = request; r.header = [Header(key: "X-Token", value: "abc")]; return r
            }
        }

        let interceptor = HeaderInterceptor()
        _ = try await makePortal(transport: transport, interceptor: interceptor).send(
            request: PortalRequest(method: .get, path: Path(url: "/me", query: nil)),
            decoding: Response.self
        )
        #expect(interceptor.adapted)
        #expect(transport.lastRequest?.header?.first(where: { $0.key.rawValue == "X-Token" })?.value.rawValue == "abc")
    }

    @Test func doNotRetry() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 401, []))
        final class NoRetryInterceptor: PortalInterceptorProtocol {}
        await #expect(throws: (any Error).self) {
            _ = try await makePortal(transport: transport, interceptor: NoRetryInterceptor()).send(
                request: PortalRequest(method: .get, path: Path(url: "/auth", query: nil)),
                decoding: Response.self
            )
        }
    }

    @Test func retryOnceSucceeds() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 401, []))

        final class RetryOnceInterceptor: PortalInterceptorProtocol {
            var retried = false
            let transport: MockTransport
            let successData: Data
            init(transport: MockTransport, successData: Data) { self.transport = transport; self.successData = successData }
            func retry(_ request: PortalRequest, dueTo error: Error) async throws -> RetryResult {
                if !retried { retried = true; transport.result = .success((successData, 200, [])); return .retry }
                return .doNotRetry
            }
        }

        let successData = encoded(Response(id: 42))
        let interceptor = RetryOnceInterceptor(transport: transport, successData: successData)
        let response = try await makePortal(transport: transport, interceptor: interceptor).send(
            request: PortalRequest(method: .get, path: Path(url: "/retry", query: nil)),
            decoding: Response.self
        )
        #expect(response.value.id == 42)
    }

    @Test func retryResponseMetadataIsFromSuccessfulAttempt() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 401, [Header(key: "X-Attempt", value: "1")]))

        final class RetryOnceInterceptor: PortalInterceptorProtocol {
            var retried = false
            let transport: MockTransport
            let successData: Data
            init(transport: MockTransport, successData: Data) { self.transport = transport; self.successData = successData }
            func retry(_ request: PortalRequest, dueTo error: Error) async throws -> RetryResult {
                if !retried {
                    retried = true
                    transport.result = .success((successData, 200, [Header(key: "X-Attempt", value: "2")]))
                    return .retry
                }
                return .doNotRetry
            }
        }

        let successData = encoded(Response(id: 99))
        let interceptor = RetryOnceInterceptor(transport: transport, successData: successData)
        let response = try await makePortal(transport: transport, interceptor: interceptor).send(
            request: PortalRequest(method: .get, path: Path(url: "/retry", query: nil)),
            decoding: Response.self
        )
        #expect(response.statusCode == 200)
        #expect(response.headers.first(where: { $0.key.rawValue == "X-Attempt" })?.value.rawValue == "2")
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
        transport.result = .success((encoded(Response(id: 1)), 200, []))
        let portal = makePortal(transport: transport)
        portal.logLevel = .none
        let response = try await portal.send(
            request: PortalRequest(method: .get, path: Path(url: "/ok", query: nil)),
            decoding: Response.self
        )
        #expect(response.value.id == 1)
    }

    @Test func releaseLogLevelStillExecutes() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 2)), 200, []))
        let portal = makePortal(transport: transport)
        portal.logLevel = .release
        let response = try await portal.send(
            request: PortalRequest(method: .get, path: Path(url: "/ok", query: nil)),
            decoding: Response.self
        )
        #expect(response.value.id == 2)
    }

    @Test func releaseLogLevelOnError() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 500, []))
        let portal = makePortal(transport: transport)
        portal.logLevel = .release
        await #expect(throws: (any Error).self) {
            _ = try await portal.send(
                request: PortalRequest(method: .get, path: Path(url: "/err", query: nil)),
                decoding: Response.self
            )
        }
    }
}

@Suite("Portal cancellation")
struct PortalCancellationTests {
    @Test func sendThrowsWhenAlreadyCancelled() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 1)), 200, []))
        let portal = makePortal(transport: transport)
        let task = Task<PortalResponse<Response>, Error> {
            try await portal.send(request: PortalRequest(method: .get, path: Path(url: "/items", query: nil)), decoding: Response.self)
        }
        task.cancel()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test func multipartSendThrowsWhenAlreadyCancelled() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 2)), 200, []))
        let portal = makePortal(transport: transport)
        let media = PortalMedia(data: Data([0x01]), key: "f", filename: "f.jpg", mimeType: "image/jpeg")
        let task = Task<PortalResponse<Response>, Error> {
            try await portal.send(
                request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
                medias: [media],
                boundary: "b",
                decoding: Response.self
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
        transport.result = .success((encoded(Response(id: 7)), 200, []))
        let media = PortalMedia(data: Data([0x01]), key: "file", filename: "img.jpg", mimeType: "image/jpeg")
        let response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
            medias: [media],
            boundary: "boundary123",
            decoding: Response.self
        )
        #expect(response.value.id == 7)
    }

    @Test func setsContentTypeHeader() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 8)), 200, []))
        let media = PortalMedia(data: Data([0xFF]), key: "avatar", filename: "av.png", mimeType: "image/png")
        _ = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
            medias: [media],
            boundary: "myboundary",
            decoding: Response.self
        )
        let contentType = transport.lastRequest?.header?.first(where: { $0.key == .contentType })?.value.rawValue
        #expect(contentType?.contains("multipart/form-data") == true)
        #expect(contentType?.contains("myboundary") == true)
    }

    @Test func withBodyParams() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 9)), 200, []))
        struct Params: Encodable { let name: String }
        let media = PortalMedia(data: Data([0xAB]), key: "doc", filename: "doc.pdf", mimeType: "application/pdf")
        let response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil), body: Body(data: Params(name: "test"), encoding: .json)),
            medias: [media],
            boundary: "b42",
            decoding: Response.self
        )
        #expect(response.value.id == 9)
    }

    @Test func decodingFailure() async throws {
        let transport = MockTransport()
        transport.result = .success(("bad".data(using: .utf8)!, 200, []))
        let media = PortalMedia(data: Data([0x00]), key: "f", filename: "f.bin", mimeType: "application/octet-stream")
        await #expect(throws: PortalError.self) {
            _ = try await makePortal(transport: transport).send(
                request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
                medias: [media],
                boundary: "b",
                decoding: Response.self
            )
        }
    }

    @Test func non2xxThrows() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 500, []))
        let media = PortalMedia(data: Data([0x00]), key: "f", filename: "f.bin", mimeType: "application/octet-stream")
        await #expect(throws: (any Error).self) {
            _ = try await makePortal(transport: transport).send(
                request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
                medias: [media],
                boundary: "b",
                decoding: Response.self
            )
        }
    }

    @Test func interceptorAdapts() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 10)), 200, []))
        final class TokenInterceptor: PortalInterceptorProtocol {
            func adapt(_ request: PortalRequest) -> PortalRequest {
                var r = request
                var headers = r.header ?? []
                headers.append(Header(key: .authorization, value: .bearer("tok")))
                r.header = headers
                return r
            }
        }
        let media = PortalMedia(data: Data([0x01]), key: "img", filename: "i.jpg", mimeType: "image/jpeg")
        let response = try await makePortal(transport: transport, interceptor: TokenInterceptor()).send(
            request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
            medias: [media],
            boundary: "b",
            decoding: Response.self
        )
        #expect(response.value.id == 10)
    }

    @Test func multipartResponseContainsStatusCode() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 11)), 201, []))
        let media = PortalMedia(data: Data([0x01]), key: "file", filename: "f.jpg", mimeType: "image/jpeg")
        let response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
            medias: [media],
            boundary: "b",
            decoding: Response.self
        )
        #expect(response.statusCode == 201)
    }

    @Test func multipartResponseContainsHeaders() async throws {
        let transport = MockTransport()
        transport.result = .success((encoded(Response(id: 12)), 200, [Header(key: "X-Upload-ID", value: "u42")]))
        let media = PortalMedia(data: Data([0x01]), key: "file", filename: "f.jpg", mimeType: "image/jpeg")
        let response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
            medias: [media],
            boundary: "b",
            decoding: Response.self
        )
        #expect(response.headers.first(where: { $0.key.rawValue == "X-Upload-ID" })?.value.rawValue == "u42")
    }
}

@Suite("Portal.send(request:) empty response")
struct PortalEmptyResponseTests {
    @Test func success() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 204, []))
        try await makePortal(transport: transport).send(
            request: PortalRequest(method: .delete, path: Path(url: "/items/1", query: nil))
        )
    }

    @Test func non2xxThrows() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 404, []))
        await #expect(throws: (any Error).self) {
            try await makePortal(transport: transport).send(
                request: PortalRequest(method: .delete, path: Path(url: "/missing", query: nil))
            )
        }
    }

    @Test func non2xxThrowsUnderlying() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 500, []))
        do {
            try await makePortal(transport: transport).send(
                request: PortalRequest(method: .get, path: Path(url: "/fail", query: nil))
            )
            Issue.record("expected throw")
        } catch let error as PortalError {
            if case .underlying(let code, _) = error { #expect(code == 500) }
            else { Issue.record("wrong error type") }
        }
    }

    @Test func retryOnInterceptor() async throws {
        let transport = MockTransport()
        var callCount = 0
        transport.resultProvider = {
            callCount += 1
            return callCount == 1 ? .success((Data(), 401, [])) : .success((Data(), 204, []))
        }
        final class RetryOnce: PortalInterceptorProtocol {
            var retried = false
            func retry(_ request: PortalRequest, dueTo error: Error) async throws -> RetryResult {
                if retried { return .doNotRetry }
                retried = true
                return .retry
            }
        }
        try await makePortal(transport: transport, interceptor: RetryOnce()).send(
            request: PortalRequest(method: .get, path: Path(url: "/auth", query: nil))
        )
        #expect(callCount == 2)
    }

    @Test func emptyResponseContainsStatusCode() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 204, []))
        let response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .delete, path: Path(url: "/items/1", query: nil))
        )
        #expect(response.statusCode == 204)
    }

    @Test func emptyResponseContainsHeaders() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 204, [Header(key: "X-Trace-ID", value: "xyz")]))
        let response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .delete, path: Path(url: "/items/1", query: nil))
        )
        #expect(response.headers.first(where: { $0.key.rawValue == "X-Trace-ID" })?.value.rawValue == "xyz")
    }

    @Test func emptyResponseContainsRequest() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 204, []))
        let response = try await makePortal(transport: transport).send(
            request: PortalRequest(method: .delete, path: Path(url: "/items/1", query: nil))
        )
        #expect(response.request.path.url.contains("/items/1"))
    }
}

@Suite("Portal.send(request:medias:boundary:) empty response")
struct PortalEmptyMultipartResponseTests {
    @Test func success() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 200, []))
        let media = PortalMedia(data: Data([0x01]), key: "file", filename: "f.jpg", mimeType: "image/jpeg")
        try await makePortal(transport: transport).send(
            request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
            medias: [media],
            boundary: "b"
        )
    }

    @Test func non2xxThrows() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 422, []))
        let media = PortalMedia(data: Data([0x01]), key: "file", filename: "f.jpg", mimeType: "image/jpeg")
        await #expect(throws: (any Error).self) {
            try await makePortal(transport: transport).send(
                request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
                medias: [media],
                boundary: "b"
            )
        }
    }

    @Test func setsContentTypeHeader() async throws {
        let transport = MockTransport()
        transport.result = .success((Data(), 201, []))
        let media = PortalMedia(data: Data([0xFF]), key: "img", filename: "img.png", mimeType: "image/png")
        try await makePortal(transport: transport).send(
            request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
            medias: [media],
            boundary: "testboundary"
        )
        let contentType = transport.lastRequest?.header?.first(where: { $0.key == .contentType })?.value.rawValue
        #expect(contentType?.contains("multipart/form-data") == true)
        #expect(contentType?.contains("testboundary") == true)
    }
}

// MARK: - Cache tests

@Suite("InMemoryCache")
struct InMemoryCacheTests {
    @Test func storeAndRetrieve() async {
        let cache = InMemoryCache()
        let entry = CachedResponse(data: Data([0x01]), statusCode: 200, expiresAt: Date().addingTimeInterval(60), etag: nil)
        await cache.set("key", response: entry)
        let hit = await cache.get("key")
        #expect(hit?.statusCode == 200)
        #expect(hit?.data == Data([0x01]))
    }

    @Test func missReturnsNil() async {
        let cache = InMemoryCache()
        let hit = await cache.get("missing")
        #expect(hit == nil)
    }

    @Test func removesEntry() async {
        let cache = InMemoryCache()
        let entry = CachedResponse(data: Data([0x01]), statusCode: 200, expiresAt: nil, etag: nil)
        await cache.set("key", response: entry)
        await cache.remove("key")
        #expect(await cache.get("key") == nil)
    }

    @Test func removeAll() async {
        let cache = InMemoryCache()
        let entry = CachedResponse(data: Data([0x01]), statusCode: 200, expiresAt: nil, etag: nil)
        await cache.set("a", response: entry)
        await cache.set("b", response: entry)
        await cache.removeAll()
        #expect(await cache.get("a") == nil)
        #expect(await cache.get("b") == nil)
    }

    @Test func expiredEntryIsDetected() {
        let expired = CachedResponse(data: Data(), statusCode: 200, expiresAt: Date().addingTimeInterval(-1), etag: nil)
        let fresh = CachedResponse(data: Data(), statusCode: 200, expiresAt: Date().addingTimeInterval(60), etag: nil)
        let noExpiry = CachedResponse(data: Data(), statusCode: 200, expiresAt: nil, etag: nil)
        #expect(expired.isExpired == true)
        #expect(fresh.isExpired == false)
        #expect(noExpiry.isExpired == false)
    }
}

@Suite("CacheHandler")
struct CacheHandlerTests {
    @Test func cacheKeyIncludesMethodAndURL() {
        let handler = CacheHandler(cache: InMemoryCache())
        let request = PortalRequest(method: .get, path: Path(url: "https://api.example.com/items", query: nil))
        let key = handler.cacheKey(for: request)
        #expect(key.contains("GET"))
        #expect(key.contains("https://api.example.com/items"))
    }

    @Test func cacheKeyIncludesSortedQuery() {
        let handler = CacheHandler(cache: InMemoryCache())
        let q1 = PortalRequest(method: .get, path: Path(url: "/items", query: [URLQueryItem(name: "b", value: "2"), URLQueryItem(name: "a", value: "1")]))
        let q2 = PortalRequest(method: .get, path: Path(url: "/items", query: [URLQueryItem(name: "a", value: "1"), URLQueryItem(name: "b", value: "2")]))
        #expect(handler.cacheKey(for: q1) == handler.cacheKey(for: q2))
    }

    @Test func reloadIgnoringReturnsNilFromCache() async {
        let cache = InMemoryCache()
        let handler = CacheHandler(cache: cache)
        let entry = CachedResponse(data: Data([0x01]), statusCode: 200, expiresAt: Date().addingTimeInterval(60), etag: nil)
        let request = PortalRequest(method: .get, path: Path(url: "/items", query: nil), cachePolicy: .reloadIgnoring)
        await cache.set(handler.cacheKey(for: request), response: entry)
        let hit = await handler.cachedEntry(for: request)
        #expect(hit == nil)
    }

    @Test func useCacheReturnsFreshEntry() async {
        let cache = InMemoryCache()
        let handler = CacheHandler(cache: cache)
        let request = PortalRequest(method: .get, path: Path(url: "/items", query: nil), cachePolicy: .useCache)
        let entry = CachedResponse(data: Data([0x42]), statusCode: 200, expiresAt: Date().addingTimeInterval(60), etag: nil)
        await cache.set(handler.cacheKey(for: request), response: entry)
        let hit = await handler.cachedEntry(for: request)
        #expect(hit?.data == Data([0x42]))
    }

    @Test func returnCacheElseLoadReturnsStaleEntry() async {
        let cache = InMemoryCache()
        let handler = CacheHandler(cache: cache)
        let request = PortalRequest(method: .get, path: Path(url: "/items", query: nil), cachePolicy: .returnCacheElseLoad)
        let stale = CachedResponse(data: Data([0x99]), statusCode: 200, expiresAt: Date().addingTimeInterval(-1), etag: nil)
        await cache.set(handler.cacheKey(for: request), response: stale)
        let hit = await handler.cachedEntry(for: request)
        #expect(hit?.data == Data([0x99]))
    }

    @Test func storeSkipsNon2xx() async {
        let cache = InMemoryCache()
        let handler = CacheHandler(cache: cache)
        let request = PortalRequest(method: .get, path: Path(url: "/fail", query: nil))
        await handler.store(data: Data([0x01]), statusCode: 404, headers: [], for: request)
        #expect(await cache.get(handler.cacheKey(for: request)) == nil)
    }

    @Test func storeWritesEntry() async {
        let cache = InMemoryCache()
        let handler = CacheHandler(cache: cache)
        let request = PortalRequest(method: .get, path: Path(url: "/items", query: nil))
        await handler.store(data: Data([0x01]), statusCode: 200, headers: [], for: request)
        #expect(await cache.get(handler.cacheKey(for: request)) != nil)
    }

    @Test func noCacheHeaderSkipsStore() async {
        let cache = InMemoryCache()
        let handler = CacheHandler(cache: cache)
        let request = PortalRequest(method: .get, path: Path(url: "/items", query: nil))
        await handler.store(data: Data([0x01]), statusCode: 200, headers: [Header(key: .cacheControl, value: .noStore)], for: request)
        #expect(await cache.get(handler.cacheKey(for: request)) == nil)
    }

    @Test func maxAgeHeaderSetsTTL() async {
        let cache = InMemoryCache()
        let handler = CacheHandler(cache: cache)
        let request = PortalRequest(method: .get, path: Path(url: "/items", query: nil))
        await handler.store(data: Data([0x01]), statusCode: 200, headers: [Header(key: .cacheControl, value: "max-age=300")], for: request)
        let entry = await cache.get(handler.cacheKey(for: request))
        #expect(entry?.expiresAt != nil)
        #expect(entry?.isExpired == false)
    }

    @Test func etagStoredFromResponseHeaders() async {
        let cache = InMemoryCache()
        let handler = CacheHandler(cache: cache)
        let request = PortalRequest(method: .get, path: Path(url: "/items", query: nil))
        await handler.store(data: Data([0x01]), statusCode: 200, headers: [Header(key: .eTag, value: "\"abc123\"")], for: request)
        let entry = await cache.get(handler.cacheKey(for: request))
        #expect(entry?.etag == "\"abc123\"")
    }
}
