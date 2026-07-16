import Testing
import Foundation
import AsyncHTTPClient
@testable import Portal
@testable import PortalNIO

// MARK: - Mock cache

actor MockNIOCache: PortalCache {
  var store: [String: CachedResponse] = [:]

  func get(_ key: String) async -> CachedResponse? { store[key] }
  func set(_ key: String, response: CachedResponse) async { store[key] = response }
  func remove(_ key: String) async { store.removeValue(forKey: key) }
  func removeAll() async { store.removeAll() }
}

// MARK: - Executor builder

private func makeTransport(
  cache: (any PortalCache)? = nil,
  handler: @escaping (HTTPClientRequest) async throws -> (Data, Int, [Header]) = { _ in (Data(), 200, []) }
) -> NIOTransport {
  NIOTransport(cache: cache, executor: handler)
}

private func request(
  url: String = "https://api.example.com/test",
  query: [URLQueryItem]? = nil,
  method: PortalRequest.HTTPMethod = .get,
  headers: [Header]? = nil,
  body: Body? = nil,
  timeout: Double? = nil,
  cachePolicy: CachePolicy? = nil
) -> PortalRequest {
  PortalRequest(
    method: method,
    path: Path(url: url, query: query),
    header: headers,
    body: body,
    scheme: nil,
    timeout: timeout,
    cachePolicy: cachePolicy
  )
}

// MARK: - Tests

@Suite("NIOTransport", .serialized)
struct NIOTransportTests {

  // MARK: Basic execute

  @Test func returnsDataAndStatusCode() async throws {
    let expected = "{\"id\":1}".data(using: .utf8)!
    let transport = makeTransport { _ in (expected, 201, []) }
    let (data, code, _) = try await transport.execute(request())
    #expect(code == 201)
    #expect(data == expected)
  }

  @Test func propagatesExecutorError() async throws {
    struct FakeError: Error {}
    let transport = makeTransport { _ in throw FakeError() }
    await #expect(throws: (any Error).self) {
      _ = try await transport.execute(request())
    }
  }

  // MARK: URL building

  @Test func noQueryItems_URLUnchanged() async throws {
    var captured: HTTPClientRequest?
    let transport = makeTransport { req in captured = req; return (Data(), 200, []) }
    _ = try await transport.execute(request(url: "https://api.example.com/items"))
    #expect(captured?.url == "https://api.example.com/items")
  }

  @Test func queryItemsAppendedToURL() async throws {
    var captured: HTTPClientRequest?
    let transport = makeTransport { req in captured = req; return (Data(), 200, []) }
    let query = [URLQueryItem(name: "page", value: "3"), URLQueryItem(name: "limit", value: "10")]
    _ = try await transport.execute(request(url: "https://api.example.com/list", query: query))
    #expect(captured?.url.contains("page=3") == true)
    #expect(captured?.url.contains("limit=10") == true)
  }

  @Test func emptyQueryArray_URLUnchanged() async throws {
    var captured: HTTPClientRequest?
    let transport = makeTransport { req in captured = req; return (Data(), 200, []) }
    _ = try await transport.execute(request(url: "https://api.example.com/empty", query: []))
    #expect(captured?.url == "https://api.example.com/empty")
  }

  // MARK: HTTP method

  @Test func httpMethodForwarded() async throws {
    var captured: HTTPClientRequest?
    let transport = makeTransport { req in captured = req; return (Data(), 200, []) }
    _ = try await transport.execute(request(method: .post))
    #expect(captured?.method.rawValue == "POST")
  }

  // MARK: Headers

  @Test func headersForwarded() async throws {
    var captured: HTTPClientRequest?
    let transport = makeTransport { req in captured = req; return (Data(), 200, []) }
    let headers = [Header(key: "X-Token", value: "abc123")]
    _ = try await transport.execute(request(headers: headers))
    #expect(captured?.headers["X-Token"].first == "abc123")
  }

  @Test func noHeaders_noCustomHeadersSet() async throws {
    var captured: HTTPClientRequest?
    let transport = makeTransport { req in captured = req; return (Data(), 200, []) }
    _ = try await transport.execute(request(headers: [Header]?.none))
    #expect(captured?.headers["X-Custom"].first == nil)
  }

  // MARK: Body encoding

  @Test func jsonBodySetsContentType() async throws {
    var captured: HTTPClientRequest?
    let transport = makeTransport { req in captured = req; return (Data(), 200, []) }
    struct Payload: Encodable { let name: String }
    let req = request(body: Body(data: Payload(name: "test"), encoding: .json))
    _ = try await transport.execute(req)
    #expect(captured?.headers["Content-Type"].first == "application/json")
    #expect(captured?.body != nil)
  }

  @Test func urlEncodedBodySetsContentType() async throws {
    var captured: HTTPClientRequest?
    let transport = makeTransport { req in captured = req; return (Data(), 200, []) }
    struct Payload: Encodable { let key: String }
    let req = request(body: Body(data: Payload(key: "value"), encoding: .urlEncoded))
    _ = try await transport.execute(req)
    #expect(captured?.headers["Content-Type"].first == "application/x-www-form-urlencoded")
    #expect(captured?.body != nil)
  }

  @Test func noBody_contentTypeNotSet() async throws {
    var captured: HTTPClientRequest?
    let transport = makeTransport { req in captured = req; return (Data(), 200, []) }
    _ = try await transport.execute(request(body: Body?.none))
    #expect(captured?.headers["Content-Type"].first == nil)
  }

  // MARK: Timeout

  @Test func timeoutSet_doesNotCrash() async throws {
    let transport = makeTransport { _ in (Data(), 200, []) }
    _ = try await transport.execute(request(timeout: 5.0))
  }

  // MARK: Response headers

  @Test func responseHeadersReturned() async throws {
    let transport = makeTransport { _ in
      (Data(), 200, [Header(key: "X-Response", value: "present")])
    }
    let (_, _, headers) = try await transport.execute(request())
    #expect(headers.contains(where: { $0.key.rawValue == "X-Response" && $0.value.rawValue == "present" }))
  }

  // MARK: Cache — no cache

  @Test func noCacheHandler_executorCalledDirectly() async throws {
    var callCount = 0
    let transport = makeTransport { _ in callCount += 1; return (Data(), 200, []) }
    _ = try await transport.execute(request())
    #expect(callCount == 1)
  }

  // MARK: Cache — miss

  @Test func cacheMiss_fetchesAndStores() async throws {
    let cache = MockNIOCache()
    let body = "fresh".data(using: .utf8)!
    let transport = makeTransport(cache: cache) { _ in
      (body, 200, [Header(key: "Cache-Control", value: "max-age=60")])
    }
    let (data, code, _) = try await transport.execute(request())
    #expect(code == 200)
    #expect(data == body)
    let stored = await cache.store.values.first
    #expect(stored != nil)
  }

  // MARK: Cache — hit, not expired

  @Test func cacheHit_notExpired_returnsCachedData() async throws {
    let cache = MockNIOCache()
    let cachedBody = "cached".data(using: .utf8)!
    let entry = CachedResponse(data: cachedBody, statusCode: 200, expiresAt: Date().addingTimeInterval(300), etag: nil)
    await cache.set("GET|https://api.example.com/test", response: entry)

    var executorCalled = false
    let transport = makeTransport(cache: cache) { _ in executorCalled = true; return (Data(), 500, []) }
    let (data, code, _) = try await transport.execute(request())
    #expect(!executorCalled)
    #expect(code == 200)
    #expect(data == cachedBody)
  }

  // MARK: Cache — expired, no etag

  @Test func cacheHit_expired_noEtag_fetchesAndStores() async throws {
    let cache = MockNIOCache()
    let staleEntry = CachedResponse(data: "stale".data(using: .utf8)!, statusCode: 200, expiresAt: Date().addingTimeInterval(-1), etag: nil)
    await cache.set("GET|https://api.example.com/test", response: staleEntry)

    let fresh = "fresh".data(using: .utf8)!
    let transport = makeTransport(cache: cache) { _ in
      (fresh, 200, [Header(key: "Cache-Control", value: "max-age=60")])
    }
    let (data, code, _) = try await transport.execute(request())
    #expect(code == 200)
    #expect(data == fresh)
  }

  // MARK: Cache — expired, etag, 304

  @Test func cacheHit_expired_etag_304_returnsCachedData() async throws {
    let cache = MockNIOCache()
    let cachedBody = "cached".data(using: .utf8)!
    let entry = CachedResponse(data: cachedBody, statusCode: 200, expiresAt: Date().addingTimeInterval(-1), etag: "\"abc\"")
    await cache.set("GET|https://api.example.com/test", response: entry)

    var capturedRequest: HTTPClientRequest?
    let transport = makeTransport(cache: cache) { req in
      capturedRequest = req
      return (Data(), 304, [Header(key: "Cache-Control", value: "max-age=60")])
    }
    let (data, code, _) = try await transport.execute(request())
    #expect(capturedRequest?.headers["If-None-Match"].first == "\"abc\"")
    #expect(code == 200)
    #expect(data == cachedBody)
  }

  // MARK: Cache — expired, etag, non-304

  @Test func cacheHit_expired_etag_non304_storesNewData() async throws {
    let cache = MockNIOCache()
    let staleBody = "stale".data(using: .utf8)!
    let entry = CachedResponse(data: staleBody, statusCode: 200, expiresAt: Date().addingTimeInterval(-1), etag: "\"old\"")
    await cache.set("GET|https://api.example.com/test", response: entry)

    let newBody = "new".data(using: .utf8)!
    let transport = makeTransport(cache: cache) { _ in
      (newBody, 200, [Header(key: "Cache-Control", value: "max-age=60")])
    }
    let (data, code, _) = try await transport.execute(request())
    #expect(code == 200)
    #expect(data == newBody)
    let stored = await cache.store.values.first
    #expect(stored?.data == newBody)
  }

  // MARK: Cache — reloadIgnoring policy

  @Test func reloadIgnoringPolicy_bypassesCache() async throws {
    let cache = MockNIOCache()
    let cachedBody = "cached".data(using: .utf8)!
    let entry = CachedResponse(data: cachedBody, statusCode: 200, expiresAt: Date().addingTimeInterval(300), etag: nil)
    await cache.set("GET|https://api.example.com/test", response: entry)

    var executorCalled = false
    let transport = makeTransport(cache: cache) { _ in executorCalled = true; return (Data(), 200, []) }
    _ = try await transport.execute(request(cachePolicy: CachePolicy.reloadIgnoring))
    #expect(executorCalled)
  }

  // MARK: Public init + defaultExecutor (integration)

  @Test func publicInit_noCacheExecutesViaDefaultExecutor() async throws {
    let transport = NIOTransport()
    let req = PortalRequest(
      method: .get,
      path: Path(url: "https://jsonplaceholder.typicode.com/todos/1", query: nil),
      scheme: nil
    )
    let (_, code, _) = try await transport.execute(req)
    #expect((100...599).contains(code))
  }

  @Test func publicInit_withCache_executesViaDefaultExecutor() async throws {
    let cache = MockNIOCache()
    let transport = NIOTransport(cache: cache)
    let req = PortalRequest(
      method: .get,
      path: Path(url: "https://jsonplaceholder.typicode.com/todos/2", query: nil),
      scheme: nil
    )
    let (_, code, _) = try await transport.execute(req)
    #expect((100...599).contains(code))
  }
}
