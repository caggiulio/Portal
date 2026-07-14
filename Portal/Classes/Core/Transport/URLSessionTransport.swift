#if canImport(UIKit) || os(macOS)
import Foundation

/// Default `HTTPTransport` backed by `URLSession.shared`.
///
/// Handles JSON and URL-encoded body encoding, and maps `HTTPURLResponse` to a status code.
///
/// Pass a `PortalCache` to enable response caching. Cache behaviour is controlled per-request
/// via `PortalRequest.cachePolicy`.
///
/// ```swift
/// // without cache (default)
/// let transport = URLSessionTransport()
///
/// // with in-memory cache
/// let transport = URLSessionTransport(cache: InMemoryCache())
/// ```
@available(macOS 12.0, iOS 15.0, *)
public struct URLSessionTransport: HTTPTransport {
  private let session: URLSession
  private let cacheHandler: CacheHandler?

  /// Creates a `URLSessionTransport`.
  ///
  /// - Parameters:
  ///   - session: The `URLSession` instance to use for HTTP requests. Defaults to `.shared`.
  ///   - cache: Optional cache backend. When `nil`, caching is disabled regardless of `PortalRequest.cachePolicy`.
  public init(session: URLSession = .shared, cache: (any PortalCache)? = nil) {
    self.session = session
    self.cacheHandler = cache.map(CacheHandler.init)
  }
  
  public func execute(_ request: PortalRequest) async throws -> (Data, Int) {
    try Task.checkCancellation()

    if let handler = cacheHandler {
      return try await executeWithCache(request, handler: handler)
    }

    return try await performRequest(request)
  }
  
  private func executeWithCache(_ request: PortalRequest, handler: CacheHandler) async throws -> (Data, Int) {
    if let cached = await handler.cachedEntry(for: request) {
      if !cached.isExpired { return (cached.data, cached.statusCode) }
      // stale + has ETag: conditional request
      if let etag = cached.etag {
        var conditional = request
        conditional.header = (conditional.header ?? []) + [Header(key: .ifNoneMatch, value: HeaderValue(stringLiteral: etag))]
        let (data, statusCode, headers) = try await performRequestWithHeaders(conditional)
        if statusCode == 304 {
          await handler.refresh(cached: cached, for: request, responseHeaders: headers)
          return (cached.data, cached.statusCode)
        }
        await handler.store(data: data, statusCode: statusCode, headers: headers, for: request)
        return (data, statusCode)
      }
    }

    let (data, statusCode, headers) = try await performRequestWithHeaders(request)
    await handler.store(data: data, statusCode: statusCode, headers: headers, for: request)
    return (data, statusCode)
  }

  private func performRequest(_ request: PortalRequest) async throws -> (Data, Int) {
    let (data, statusCode, _) = try await performRequestWithHeaders(request)
    return (data, statusCode)
  }

  private func performRequestWithHeaders(_ request: PortalRequest) async throws -> (Data, Int, [String: String]) {
    guard let url = buildURL(from: request) else { throw PortalError.invalidUrl }
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = request.method.rawValue
    if let timeout = request.timeout { urlRequest.timeoutInterval = timeout }
    request.header?.forEach { urlRequest.setValue($0.value.rawValue, forHTTPHeaderField: $0.key.rawValue) }
    if let body = request.body {
      switch body.encoding {
      case .json:
        if let data = try? JSONEncoder().encode(AnyEncodable(body.data)) {
          urlRequest.httpBody = data
          urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
      case .urlEncoded:
        if let dict = body.data.dictionary {
          let encoded = dict.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
          urlRequest.httpBody = encoded.data(using: .utf8)
          urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
      }
    }
    let (data, response) = try await session.data(for: urlRequest)
    guard let httpResponse = response as? HTTPURLResponse else { throw PortalError.invalidHTTPResponse }
    let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, pair in
      if let key = pair.key as? String, let value = pair.value as? String { result[key] = value }
    }
    return (data, httpResponse.statusCode, headers)
  }

  private func buildURL(from request: PortalRequest) -> URL? {
    var components = URLComponents(string: request.path.url)
    components?.queryItems = request.path.query
    return components?.url
  }
}

private struct AnyEncodable: Encodable {
  private let _encode: (Encoder) throws -> Void
  init(_ value: Encodable) { _encode = value.encode }
  func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
#endif
