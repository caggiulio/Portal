#if canImport(UIKit) || os(macOS)
import Foundation

/// Default `HTTPTransport` backed by `URLSession.shared`.
/// Handles JSON and URL-encoded body encoding, and maps `HTTPURLResponse` to a status code.
@available(macOS 12.0, iOS 15.0, *)
public struct URLSessionTransport: HTTPTransport {
  private let session: URLSession
  
  public init(session: URLSession = .shared) {
    self.session = session
  }
  
  public func execute(_ request: PortalRequest) async throws -> (Data, Int) {
    try Task.checkCancellation()
    guard let url = buildURL(from: request) else {
      throw PortalError.invalidUrl
    }
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = request.method.rawValue
    if let timeout = request.timeout {
      urlRequest.timeoutInterval = timeout
    }
    
    request.header?.forEach { header in
      urlRequest.setValue(header.value.rawValue, forHTTPHeaderField: header.key.rawValue)
    }
    
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
    guard let httpResponse = response as? HTTPURLResponse else {
      throw PortalError.invalidHTTPResponse
    }
    return (data, httpResponse.statusCode)
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
