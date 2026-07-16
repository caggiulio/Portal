import Portal
import AsyncHTTPClient
import Foundation
import NIOFoundationCompat
import NIOHTTP1

/// `HTTPTransport` backed by Swift NIO / `AsyncHTTPClient`.
///
/// Cross-platform: works on Linux and Android (via Swift Android toolchain) where `URLSession` is unavailable.
///
/// Pass a `PortalCache` to enable response caching. Cache behaviour is controlled per-request
/// via `PortalRequest.cachePolicy`.
///
/// ```swift
/// // without cache (default)
/// let transport = NIOTransport()
///
/// // with in-memory cache
/// let transport = NIOTransport(cache: InMemoryCache())
/// ```
@available(macOS 10.15, iOS 13.0, *)
public struct NIOTransport: HTTPTransport {
  private let cacheHandler: CacheHandler?

  /// Creates a `NIOTransport`.
  ///
  /// - Parameter cache: Optional cache backend. When `nil`, caching is disabled regardless of `PortalRequest.cachePolicy`.
  public init(cache: (any PortalCache)? = nil) {
    self.cacheHandler = cache.map(CacheHandler.init)
  }

  public func execute(_ request: PortalRequest) async throws -> (Data, Int, [Header]) {
    if let handler = cacheHandler {
      return try await executeWithCache(request, handler: handler)
    }
    return try await performRequestWithHeaders(request)
  }
}

// MARK: - Private

@available(macOS 10.15, iOS 13.0, *)
private extension NIOTransport {
  func executeWithCache(_ request: PortalRequest, handler: CacheHandler) async throws -> (Data, Int, [Header]) {
    if let cached = await handler.cachedEntry(for: request) {
      if !cached.isExpired { return (cached.data, cached.statusCode, []) }
      if let etag = cached.etag {
        var conditional = request
        conditional.header = (conditional.header ?? []) + [Header(key: .ifNoneMatch, value: HeaderValue(stringLiteral: etag))]
        let (data, statusCode, headers) = try await performRequestWithHeaders(conditional)
        if statusCode == 304 {
          await handler.refresh(cached: cached, for: request, responseHeaders: headers)
          return (cached.data, cached.statusCode, [])
        }
        await handler.store(data: data, statusCode: statusCode, headers: headers, for: request)
        return (data, statusCode, headers)
      }
    }
    let (data, statusCode, headers) = try await performRequestWithHeaders(request)
    await handler.store(data: data, statusCode: statusCode, headers: headers, for: request)
    return (data, statusCode, headers)
  }

  func performRequestWithHeaders(_ request: PortalRequest) async throws -> (Data, Int, [Header]) {
    var httpRequest = HTTPClientRequest(url: buildURL(from: request))
    httpRequest.method = HTTPMethod(rawValue: request.method.rawValue)
    if let timeout = request.timeout {
      httpRequest.tlsConfiguration?.shutdownTimeout = .seconds(Int64(timeout))
    }
    request.header?.forEach { header in
      httpRequest.headers.add(name: header.key.rawValue, value: header.value.rawValue)
    }
    if let body = request.body {
      switch body.encoding {
      case .json:
        if let data = try? JSONEncoder().encode(AnyEncodable(body.data)) {
          httpRequest.headers.add(name: "Content-Type", value: "application/json")
          httpRequest.body = .bytes(data)
        }
      case .urlEncoded:
        if let jsonData = try? JSONEncoder().encode(AnyEncodable(body.data)),
           let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
          let encoded = dict.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
          if let data = encoded.data(using: .utf8) {
            httpRequest.headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
            httpRequest.body = .bytes(data)
          }
        }
      }
    }
    try Task.checkCancellation()
    let response = try await withTaskCancellationHandler {
      try await HTTPClient.shared.execute(httpRequest, timeout: .seconds(30))
    } onCancel: {
      // AsyncHTTPClient does not auto-cancel on Task cancellation;
      // checkCancellation above covers the pre-flight case.
    }
    try Task.checkCancellation()
    let buffer = try await response.body.collect(upTo: 10 * 1024 * 1024)
    let data = Data(buffer: buffer)
    let headers: [Header] = response.headers.map { Header(key: HeaderKey(stringLiteral: $0.name), value: HeaderValue(stringLiteral: $0.value)) }
    return (data, Int(response.status.code), headers)
  }

  func buildURL(from request: PortalRequest) -> String {
    guard let queryItems = request.path.query, !queryItems.isEmpty else { return request.path.url }
    var components = URLComponents(string: request.path.url)
    components?.queryItems = queryItems
    return components?.url?.absoluteString ?? request.path.url
  }
}

private struct AnyEncodable: Encodable {
  private let _encode: (Encoder) throws -> Void
  init(_ value: Encodable) { _encode = value.encode }
  func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
