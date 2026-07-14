//
//  CachePolicy.swift
//  Portal
//
//  Copyright © 2026 Nunzio Giulio Caggegi All rights reserved.
//

/// Controls how `CachingTransport` reads from and writes to the response cache.
public enum CachePolicy: Sendable {
  /// Return a cached response if one exists and has not expired; otherwise fetch from the network and cache the result.
  case useCache

  /// Always fetch from the network. The response is **not** stored in the cache.
  case reloadIgnoring

  /// Return a cached response if one exists — even if it has expired — before falling back to a network fetch.
  case returnCacheElseLoad
}
