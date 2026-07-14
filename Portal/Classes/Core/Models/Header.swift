//
//  Header.swift
//  Portal
//
//  Copyright © 2026 Nunzio Giulio Caggegi All rights reserved.
//

/// A single HTTP header field composed of a typed key and value.
///
/// Use preset static members for common headers, or pass raw strings when a preset is not available:
/// ```swift
/// Header(key: .contentType, value: .applicationJSON)
/// Header(key: .authorization, value: .bearer(token))
/// Header(key: "X-App-Version", value: "2.0.1")
/// ```
public struct Header {
  /// The HTTP header field name.
  public let key: HeaderKey
  /// The HTTP header field value.
  public let value: HeaderValue

  /// Creates a header with a typed key and value.
  public init(key: HeaderKey, value: HeaderValue) {
    self.key = key
    self.value = value
  }
}

// MARK: - HeaderKey

/// A typed HTTP header field name.
///
/// Preset static members cover the most common header names.
/// Pass any raw string to use a non-preset field name:
/// ```swift
/// let key: HeaderKey = "X-Correlation-ID"
/// ```
public struct HeaderKey: ExpressibleByStringLiteral, Hashable {
  /// The raw header field name string sent on the wire.
  public let rawValue: String

  public init(stringLiteral value: String) {
    self.rawValue = value
  }

  // MARK: Content

  /// `Content-Type`
  public static let contentType: HeaderKey = "Content-Type"
  /// `Content-Encoding`
  public static let contentEncoding: HeaderKey = "Content-Encoding"

  // MARK: Accept

  /// `Accept`
  public static let accept: HeaderKey = "Accept"
  /// `Accept-Language`
  public static let acceptLanguage: HeaderKey = "Accept-Language"
  /// `Accept-Encoding`
  public static let acceptEncoding: HeaderKey = "Accept-Encoding"

  // MARK: Auth

  /// `Authorization`
  public static let authorization: HeaderKey = "Authorization"

  // MARK: Cache

  /// `Cache-Control`
  public static let cacheControl: HeaderKey = "Cache-Control"
  /// `If-None-Match`
  public static let ifNoneMatch: HeaderKey = "If-None-Match"
  /// `ETag`
  public static let eTag: HeaderKey = "ETag"

  // MARK: Misc

  /// `User-Agent`
  public static let userAgent: HeaderKey = "User-Agent"
  /// `X-Requested-With`
  public static let xRequestedWith: HeaderKey = "X-Requested-With"
  /// `X-Correlation-ID`
  public static let xCorrelationId: HeaderKey = "X-Correlation-ID"
}

// MARK: - HeaderValue

/// A typed HTTP header field value.
///
/// Preset static members and factory methods cover the most common values.
/// Pass any raw string for a non-preset value:
/// ```swift
/// let value: HeaderValue = "my-custom-value"
/// ```
public struct HeaderValue: ExpressibleByStringLiteral {
  /// The raw value string sent on the wire.
  public let rawValue: String

  public init(stringLiteral value: String) {
    self.rawValue = value
  }

  // MARK: Content types

  /// `application/json`
  public static let applicationJSON: HeaderValue = "application/json"
  /// `application/x-www-form-urlencoded`
  public static let applicationFormURLEncoded: HeaderValue = "application/x-www-form-urlencoded"
  /// `application/octet-stream`
  public static let applicationOctetStream: HeaderValue = "application/octet-stream"
  /// `text/plain`
  public static let textPlain: HeaderValue = "text/plain"
  /// `text/html`
  public static let textHTML: HeaderValue = "text/html"

  // MARK: Auth

  /// `Bearer <token>`
  public static func bearer(_ token: String) -> HeaderValue { HeaderValue(stringLiteral: "Bearer \(token)") }
  /// `Basic <credentials>`
  public static func basic(_ credentials: String) -> HeaderValue { HeaderValue(stringLiteral: "Basic \(credentials)") }

  // MARK: Multipart

  /// `multipart/form-data; boundary=<boundary>`
  public static func multipartFormData(boundary: String) -> HeaderValue {
    HeaderValue(stringLiteral: "multipart/form-data; boundary=\(boundary)")
  }

  // MARK: Encoding

  /// `gzip`
  public static let gzip: HeaderValue = "gzip"
  /// `identity`
  public static let identity: HeaderValue = "identity"

  // MARK: Cache

  /// `no-cache`
  public static let noCache: HeaderValue = "no-cache"
  /// `no-store`
  public static let noStore: HeaderValue = "no-store"

  // MARK: Misc

  /// `XMLHttpRequest` — used with `X-Requested-With` to identify AJAX requests.
  public static let xmlHttpRequest: HeaderValue = "XMLHttpRequest"
}
