//
//  PortalCache.swift
//  Portal
//
//  Copyright © 2026 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

/// A single cached HTTP response entry.
public struct CachedResponse: Sendable {
  /// The raw response body.
  public let data: Data
  /// The HTTP status code of the original response.
  public let statusCode: Int
  /// The date after which this entry is considered stale. `nil` means the entry never expires.
  public let expiresAt: Date?
  /// The ETag returned by the server, used to send conditional `If-None-Match` requests.
  public let etag: String?

  /// `true` when `expiresAt` is set and the current time is past it.
  public var isExpired: Bool {
    guard let expiresAt else { return false }
    return Date() >= expiresAt
  }

  /// Creates a new `CachedResponse`.
  ///
  /// - Parameters:
  ///   - data: Raw response body.
  ///   - statusCode: HTTP status code of the original response.
  ///   - expiresAt: Absolute expiry date derived from `Cache-Control: max-age`. Pass `nil` for no expiry.
  ///   - etag: Value of the `ETag` response header, if present.
  public init(data: Data, statusCode: Int, expiresAt: Date?, etag: String?) {
    self.data = data
    self.statusCode = statusCode
    self.expiresAt = expiresAt
    self.etag = etag
  }
}

/// Defines the storage contract for `CachingTransport`.
///
/// Implement this protocol to provide a custom cache backend (disk, keychain, shared memory, etc.).
/// All methods must be safe to call from concurrent async contexts.
public protocol PortalCache: Sendable {
  /// Returns the cached response for `key`, or `nil` if no entry exists.
  func get(_ key: String) async -> CachedResponse?

  /// Stores `response` under `key`, replacing any previous entry.
  func set(_ key: String, response: CachedResponse) async

  /// Removes the entry for `key`, if one exists.
  func remove(_ key: String) async

  /// Removes all entries from the cache.
  func removeAll() async
}
