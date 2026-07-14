//
//  CacheHandler.swift
//  Portal
//
//  Copyright © 2026 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

/// Internal helper used by `URLSessionTransport` and `NIOTransport` to apply cache read/write logic.
public struct CacheHandler {
  public let cache: any PortalCache

  public init(cache: any PortalCache) {
    self.cache = cache
  }

  public func cacheKey(for request: PortalRequest) -> String {
    var key = request.method.rawValue + "|" + request.path.url
    if let items = request.path.query {
      key += "?" + items.map { "\($0.name)=\($0.value ?? "")" }.sorted().joined(separator: "&")
    }
    return key
  }

  /// Returns a cached entry to use, or `nil` if the transport should fetch from the network.
  /// When the returned entry has an `etag`, the caller should inject `If-None-Match` into the outgoing request.
  public func cachedEntry(for request: PortalRequest) async -> CachedResponse? {
    let policy = request.cachePolicy ?? .useCache
    guard policy != .reloadIgnoring else { return nil }
    let key = cacheKey(for: request)
    guard let cached = await cache.get(key) else { return nil }
    if !cached.isExpired || policy == .returnCacheElseLoad { return cached }
    return cached // stale + .useCache: caller does conditional request with ETag
  }

  /// Stores the response if the policy and status code allow it.
  public func store(data: Data, statusCode: Int, headers: [String: String], for request: PortalRequest) async {
    let policy = request.cachePolicy ?? .useCache
    guard policy != .reloadIgnoring, (200...299).contains(statusCode) else { return }
    let maxAge = parseMaxAge(from: headers) ?? 60
    guard maxAge > 0 else { return }
    let key = cacheKey(for: request)
    let expiresAt = Date().addingTimeInterval(TimeInterval(maxAge))
    let etag = headers["etag"] ?? headers["ETag"]
    let entry = CachedResponse(data: data, statusCode: statusCode, expiresAt: expiresAt, etag: etag)
    await cache.set(key, response: entry)
  }

  /// Refreshes the TTL of an existing entry (called after a 304 response).
  public func refresh(cached: CachedResponse, for request: PortalRequest, responseHeaders: [String: String]) async {
    await store(data: cached.data, statusCode: cached.statusCode, headers: responseHeaders, for: request)
  }

  private func parseMaxAge(from headers: [String: String]) -> Int? {
    let value = headers["cache-control"] ?? headers["Cache-Control"] ?? ""
    for directive in value.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) {
      let lower = directive.lowercased()
      if lower.hasPrefix("no-store") || lower.hasPrefix("no-cache") { return 0 }
      if lower.hasPrefix("max-age="), let seconds = Int(directive.dropFirst("max-age=".count)) { return seconds }
    }
    return nil
  }
}
