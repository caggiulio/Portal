//
//  InMemoryCache.swift
//  Portal
//
//  Copyright © 2026 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

/// A thread-safe, in-process `PortalCache` backed by a Swift actor.
///
/// Entries live only for the lifetime of the process. Use this cache when persistence across
/// app launches is not required. It is cross-platform: no Foundation persistence APIs are used.
public actor InMemoryCache: PortalCache {
  private var store: [String: CachedResponse] = [:]

  /// Creates an empty `InMemoryCache`.
  public init() {}

  public func get(_ key: String) async -> CachedResponse? {
    store[key]
  }

  public func set(_ key: String, response: CachedResponse) async {
    store[key] = response
  }

  public func remove(_ key: String) async {
    store.removeValue(forKey: key)
  }

  public func removeAll() async {
    store.removeAll()
  }
}
