//
//  PortalRequest.swift
//  Portal
//
//  Copyright © 2026 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

/// Describes a single HTTP request passed to `Portal.send(request:)`.
public struct PortalRequest {
  
  // MARK: - Public properties
  
  /// HTTP verb.
  public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
  }
  
  /// URL scheme for this request.
  public enum Scheme: String {
    case http
    case https
  }
  
  /// How the body payload is serialised onto the wire.
  public enum Encoding {
    /// Serialises as `application/json`.
    case json
    /// Serialises as `application/x-www-form-urlencoded`.
    case urlEncoded
  }
  
  /// HTTP method for this request.
  public var method: HTTPMethod
  /// Destination URL and optional query items.
  public var path: Path
  /// HTTP headers to include with the request.
  public var header: [Header]?
  /// Optional request body.
  public var body: Body?
  /// Overrides the URL scheme. Replaces whatever scheme is in `baseURL`.
  public var scheme: Scheme?
  /// The request timeout in seconds.
  public var timeout: TimeInterval?
  /// Controls how the transport reads from and writes to the response cache.
  /// Has no effect when the transport was not initialised with a `PortalCache`. Defaults to `nil` (treated as `.useCache`).
  public var cachePolicy: CachePolicy?
  
  // MARK: - Object lifecycle
  
  /// Creates a new PortalRequest describing a single HTTP call.
  ///
  /// - Parameters:
  ///   - method: The HTTP verb to use for the request (for example, `.get`, `.post`, `.put`, `.patch`, or `.delete`).
  ///   - path: A tuple containing the destination URL string and optional query items to append to the URL.
  ///           Provide the raw URL in `url` and any query parameters as `[URLQueryItem]` in `query`.
  ///   - header: Optional HTTP headers to include with the request. Defaults to `nil`.
  ///   - body: Optional request body as a tuple containing an `Encodable` payload and its wire `Encoding` strategy
  ///           (e.g., `.json` or `.urlEncoded`). Defaults to `nil`.
  ///   - scheme: Optional URL scheme override that replaces the scheme in the base URL (e.g., `.http` or `.https`).
  ///             Defaults to `.http`.
  ///   - timeout: Optional timeout request in seconds. Default to 30 seconds.
  public init(method: HTTPMethod, path: Path, header: [Header]? = nil, body: Body? = nil, scheme: Scheme? = .http, timeout: TimeInterval? = 30, cachePolicy: CachePolicy? = nil) {
    self.method = method
    self.path = path
    self.header = header
    self.body = body
    self.scheme = scheme
    self.timeout = timeout
    self.cachePolicy = cachePolicy
  }
}

/// Represents the destination of a request, composed of a base URL string and optional query parameters.
///
/// Use `Path` to describe where a `PortalRequest` should be sent. The `url` is a raw, absolute or relative URL string,
/// and `query` contains any additional `URLQueryItem` values that should be appended to the URL.
///
/// - Note: `query` items are appended to the `url` during request construction; existing query parameters in `url` may be preserved
///         depending on the URL composition logic elsewhere in the networking layer.
///
/// - Parameters:
///   - url: The base URL string for the request. This can be absolute (e.g., "https://api.example.com/v1/items")
///          or relative to a configured base URL (e.g., "/v1/items") depending on how `Portal` is set up.
///   - query: Optional array of `URLQueryItem` to be encoded into the URL's query string (e.g., `?page=1&limit=20`).
public struct Path {
  /// Base URL string for the request (absolute or relative).
  public let url: String
  /// Optional query parameters to append to the URL.
  public let query: [URLQueryItem]?
  
  /// Creates a new `Path` describing a destination URL and optional query parameters.
  ///
  /// - Parameters:
  ///   - url: The base URL string for the request. This may be an absolute URL (e.g., "https://api.example.com/v1/items")
  ///           or a relative path (e.g., "/v1/items") depending on how the client composes requests.
  ///   - query: Optional array of `URLQueryItem` values to be appended to the URL's query string (e.g., `?page=1&limit=20`).
  public init(url: String, query: [URLQueryItem]?) {
    self.url = url
    self.query = query
  }
}

/// Represents the request body payload and how it should be encoded on the wire.
///
/// Use `Body` to provide an `Encodable` value together with the desired `Encoding`
/// (e.g., `.json` or `.urlEncoded`) when constructing a `PortalRequest`.
public struct Body {
  /// The payload to send with the request. Any type conforming to `Encodable` is accepted
  /// and will be serialized according to the specified `encoding`.
  public let data: Encodable
  
  /// The wire format to use when serializing `data` (for example, JSON or URL-encoded form data).
  public let encoding: PortalRequest.Encoding

  /// Creates a new request body with the given payload and wire encoding.
  ///
  /// - Parameters:
  ///   - data: The `Encodable` payload to serialize into the HTTP body.
  ///   - encoding: The wire format to use when serializing the payload (e.g., `.json` or `.urlEncoded`).
  public init(data: Encodable, encoding: PortalRequest.Encoding) {
    self.data = data
    self.encoding = encoding
  }
}

