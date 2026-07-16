<p align="center">
  <img src="assets/logo.png" alt="Portal" width="320"/>
</p>

<p align="center">
  <strong>A Swift networking library that runs everywhere — including Android.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-5.10+-F05138?style=flat&logo=swift&logoColor=white"/>
  <img src="https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20Linux%20%7C%20Android-blue?style=flat"/>
  <img src="https://img.shields.io/badge/SPM-compatible-brightgreen?style=flat"/>
  <img src="https://img.shields.io/badge/License-MIT-lightgrey?style=flat"/>
  <img src="https://img.shields.io/badge/Test%20Coverage-~98%25-brightgreen?style=flat&logo=checkmarx"/>
</p>

---

## Why Portal?

Portal is a lightweight, protocol-driven HTTP networking library written entirely in Swift. What makes it unique: **it runs on Android**. The `PortalNIO` target is built on [SwiftNIO](https://github.com/apple/swift-nio) and [AsyncHTTPClient](https://github.com/swift-server/async-http-client), both of which support Linux and [Swift on Android](https://www.swift.org/documentation/android/), giving you a single networking stack across iOS, macOS, Linux, and Android — no Kotlin, no Java.

---

## Features

- **Cross-platform** — iOS 15+, macOS 12+, Linux, Android (via Swift on Android)
- **Async/Await** — native Swift concurrency throughout
- **Dual transport layer** — `URLSessionTransport` for Apple platforms, `NIOTransport` for Linux/Android
- **Response caching** — per-request `CachePolicy`, ETag / `Cache-Control` support (currently in-memory only)
- **Interceptor pattern** — adapt requests and implement retry logic in one place
- **Multipart uploads** — built-in support for file and media uploads
- **Trace logger** — configurable request/response console logging
- **Protocol-oriented** — mock any transport or portal instance in tests

---

## Installation

### Swift Package Manager

Add Portal to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/caggiulio/Portal.git", from: "1.0.0")
]
```

Then add the target you need:

| Target | Use when |
|--------|----------|
| `Portal` | iOS / macOS (uses `URLSession`) |
| `PortalNIO` | Linux / Android (uses SwiftNIO + AsyncHTTPClient) |

```swift
.target(
    name: "MyApp",
    dependencies: [
        // Apple platforms
        .product(name: "Portal", package: "Portal"),

        // OR Linux / Android
        .product(name: "PortalNIO", package: "Portal"),
    ]
)
```

---

## Quick Start

### 1. Create a Portal instance

**Apple platforms (URLSession)**

```swift
import Portal

let portal = Portal(
    baseURL: "https://api.example.com",
    transport: URLSessionTransport()
)
```

**Linux / Android (NIO)**

```swift
import PortalNIO

let portal = Portal(
    baseURL: "https://api.example.com",
    transport: NIOTransport()
)
```

### 2. Define a request

```swift
let request = PortalRequest(
    method: .get,
    path: (url: "/users/42", query: nil),
    header: ["Authorization": "Bearer \(token)"]
)
```

### 3. Send it

```swift
struct User: Decodable {
    let id: Int
    let name: String
}

let response: PortalResponse<User> = try await portal.send(request: request)
let user = response.value          // decoded body
let status = response.statusCode   // e.g. 200
let headers = response.headers     // [Header]
let sent = response.request        // adapted PortalRequest
```

---

## Interceptors

Interceptors are the extension point for cross-cutting concerns: authentication, token refresh, logging, header injection, and retry policies. Portal's interceptor system is split into two composable protocols that are both satisfied by `PortalInterceptorProtocol`.

### Protocol overview

```
PortalInterceptorProtocol
├── RequestAdapter    →  adapt(_ request:) -> PortalRequest
└── RetryAdapter      →  retry(_ request:, dueTo error:) async throws -> RetryResult
```

Both methods have **default no-op implementations**, so you only override what you need.

---

### `RequestAdapter` — mutate requests before they are sent

`adapt(_:)` is called for every outgoing request, before the transport layer touches it. Return a modified copy to inject headers, override the scheme, sign the request, or anything else.

```swift
class AuthInterceptor: PortalInterceptorProtocol {
    func adapt(_ request: PortalRequest) -> PortalRequest {
        var r = request
        var headers = r.header ?? [:]
        headers["Authorization"] = "Bearer \(TokenStore.current)"
        r.header = headers
        return r
    }
}
```

Common `adapt` use-cases:

| Use-case | What to mutate |
|----------|----------------|
| Bearer token | `header["Authorization"]` |
| API key | `header["X-Api-Key"]` |
| Device / platform info | `header["X-Platform"]` |
| Force HTTPS | `request.scheme = .https` |
| Locale | `header["Accept-Language"]` |

---

### `RetryAdapter` — decide whether to retry a failed request

`retry(_:dueTo:)` is called whenever a request ends with a non-2xx status or a network error. Return `.retry` to re-send the original request, or `.doNotRetry` to propagate the error.

```swift
enum RetryResult {
    case retry
    case doNotRetry
}
```

> **Note:** Portal does not apply a retry limit automatically. If you always return `.retry`, the request will loop indefinitely. Guard against that in your implementation (see examples below).

---

### Examples

#### Token refresh on 401

```swift
class TokenRefreshInterceptor: PortalInterceptorProtocol {
    private var retryCount = 0
    private let maxRetries = 1

    func adapt(_ request: PortalRequest) -> PortalRequest {
        var r = request
        var headers = r.header ?? [:]
        headers["Authorization"] = "Bearer \(TokenStore.current)"
        r.header = headers
        return r
    }

    func retry(_ request: PortalRequest, dueTo error: Error) async throws -> RetryResult {
        guard
            case PortalError.underlying(let statusCode, _) = error,
            statusCode == 401,
            retryCount < maxRetries
        else { return .doNotRetry }

        retryCount += 1
        try await TokenStore.refresh()   // await new token
        return .retry                    // Portal will call adapt() again on the retried request
    }
}
```

#### Exponential back-off on 5xx

```swift
class RetryInterceptor: PortalInterceptorProtocol {
    private var attempt = 0
    private let maxAttempts = 3

    func retry(_ request: PortalRequest, dueTo error: Error) async throws -> RetryResult {
        guard
            case PortalError.underlying(let statusCode, _) = error,
            (500...599).contains(statusCode),
            attempt < maxAttempts
        else { return .doNotRetry }

        let delay = pow(2.0, Double(attempt))   // 1s, 2s, 4s
        attempt += 1
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return .retry
    }
}
```

#### Adapter-only interceptor (no retry)

When you only need to mutate requests, omit `retry` — the default implementation returns `.doNotRetry`.

```swift
class CommonHeadersInterceptor: PortalInterceptorProtocol {
    let appVersion: String

    func adapt(_ request: PortalRequest) -> PortalRequest {
        var r = request
        var headers = r.header ?? [:]
        headers["X-App-Version"] = appVersion
        headers["X-Platform"] = "iOS"
        r.header = headers
        return r
    }
}
```

---

### Wiring an interceptor to Portal

```swift
let portal = Portal(
    baseURL: "https://api.example.com",
    transport: URLSessionTransport(),
    interceptor: TokenRefreshInterceptor()
)
```

One `Portal` instance accepts one interceptor. Chain multiple concerns by composing them inside a single interceptor class.

---

## Multipart Uploads

```swift
let image = PortalMedia(
    key: "avatar",
    filename: "photo.jpg",
    mimeType: "image/jpeg",
    data: imageData
)

let boundary = UUID().uuidString
let response: PortalResponse<UploadResponse> = try await portal.send(
    request: uploadRequest,
    medias: [image],
    boundary: boundary
)
```

---

## Caching

Portal supports response caching via a `PortalCache` protocol. Pass a cache instance when constructing the transport — both `URLSessionTransport` and `NIOTransport` accept one.

> **Note:** At the moment, only `InMemoryCache` is provided. Entries live for the lifetime of the process and are not persisted to disk.

```swift
// Apple platforms
let portal = Portal(
    baseURL: "https://api.example.com",
    transport: URLSessionTransport(cache: InMemoryCache())
)

// Linux / Android
let portal = Portal(
    baseURL: "https://api.example.com",
    transport: NIOTransport(cache: InMemoryCache())
)
```

Control caching behaviour per request via `cachePolicy`:

```swift
// default: return cached response if fresh, otherwise fetch
PortalRequest(method: .get, path: Path(url: "/items", query: nil))

// always fetch, skip cache entirely
PortalRequest(method: .get, path: Path(url: "/items", query: nil), cachePolicy: .reloadIgnoring)

// return cached even if stale, fall back to network only if absent
PortalRequest(method: .get, path: Path(url: "/items", query: nil), cachePolicy: .returnCacheElseLoad)
```

Cache TTL is derived from the `Cache-Control: max-age=N` response header (default 60 s when absent). Responses with `no-store` or `no-cache` are never cached. When a cached entry carries an `ETag`, Portal sends `If-None-Match` automatically and reuses the cached body on a `304 Not Modified`.

Implement `PortalCache` to provide a custom backend (disk, keychain, shared memory, etc.):

```swift
public protocol PortalCache: Sendable {
    func get(_ key: String) async -> CachedResponse?
    func set(_ key: String, response: CachedResponse) async
    func remove(_ key: String) async
    func removeAll() async
}
```

---

## Logging

```swift
portal.logLevel = .debug  // prints request + response details
portal.logLevel = .none   // silence all output
```

---

## Architecture

```
Portal/
├── Portal/
│   └── Classes/
│       ├── Core/
│       │   ├── Base/          # Portal + PortalProtocol
│       │   ├── Transport/     # HTTPTransport + URLSessionTransport
│       │   ├── Models/        # PortalRequest, PortalMedia, PortalResponse
│       │   ├── Error/         # PortalError
│       │   ├── Interceptor/   # PortalInterceptorProtocol
│       │   └── Logger/        # PortalTraceLogger
│       └── Extensions/
└── PortalNIO/
    └── NIOTransport.swift     # SwiftNIO transport (Linux / Android)
```

---

## Android Support

Portal runs on Android through [Swift on Android](https://www.swift.org/documentation/android/). Use the `PortalNIO` target — it has zero Apple-platform dependencies. The underlying `AsyncHTTPClient` and `SwiftNIO` libraries have full Linux/Android support.

A typical Android integration uses the Swift Android SDK toolchain to compile your Swift networking layer and bridge it to the Android app via JNI or a higher-level framework such as [Skip](https://skip.tools).

---

## Testing

Portal ships with a full test suite written in [Swift Testing](https://developer.apple.com/xcode/swift-testing/), achieving **~98% line coverage**.

```
swift test --enable-code-coverage
```

---

## Requirements

| Target | Swift | Platform |
|--------|-------|----------|
| `Portal` | 5.10+ | iOS 15+, macOS 12+ |
| `PortalNIO` | 5.10+ | Linux, Android, macOS 12+ |

---

## License

Portal is released under the MIT license. See [LICENSE](LICENSE) for details.

---

<p align="center">Made with Swift — runs everywhere.</p>
