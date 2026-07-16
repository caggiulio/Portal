//
//  Portal.swift
//  Portal
//
//  Copyright © 2026 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

// MARK: - Portal

/// Public class used to build an object that will deal with HTTP calls. It's builded with the `baseURL` and the `PortalInterceptorProtocol` passed on init.
public class Portal: NSObject, PortalProtocol {
  
  // MARK: - Public methods

  /// Prints network calls in the console.
  /// Values available are .none and .debug(default).
  /// - `.none`: The logger is off.
  /// - `.debug`: All the network informations(request and response) are printed.
  public var logLevel: PortalTraceLoggerLevel {
    get { return logger.logLevel }
    set { logger.logLevel = newValue }
  }

  // MARK: - Business logic properties

  /// The base URL.
  private let baseURL: String

  /// The interceptor is used to adapt `URL` request and retry mechanism
  private var interceptor: PortalInterceptorProtocol?

  /// The `HTTPTransport`
  private let transport: HTTPTransport

  /// Instance of `PortalTraceLogger`
  private var logger = PortalTraceLogger()

  /// The init of a `Portal` instance.
  /// - Parameter baseURL: The host baseURL for this instance of `Portal`
  /// - Parameter transport: The transport layer used to execute HTTP requests
  /// - Parameter interceptor: The interceptor is used to adapt `URL` request and retry mechanism
  public init(baseURL: String, transport: HTTPTransport, interceptor: PortalInterceptorProtocol? = nil) {
    self.baseURL = baseURL
    self.transport = transport
    self.interceptor = interceptor
  }

  // MARK: - Protocol

  @available(macOS 12.0, iOS 15.0, *)
  public func send<SuccessResponse: Decodable>(request: PortalRequest, decoding: SuccessResponse.Type) async throws -> PortalResponse<SuccessResponse> {
    try await send(request: request)
  }

  @available(macOS 12.0, iOS 15.0, *)
  @discardableResult
  public func send(request: PortalRequest) async throws -> PortalResponse<Void> {
    try Task.checkCancellation()
    var adaptedRequest = interceptor?.adapt(request) ?? request
    adaptedRequest.path = Path(url: baseURL + adaptedRequest.path.url, query: adaptedRequest.path.query)
    if let scheme = adaptedRequest.scheme {
      adaptedRequest.path = Path(url: applyScheme(scheme, to: adaptedRequest.path.url), query: adaptedRequest.path.query)
    }
    logger.logRequest(adaptedRequest)
    let (data, statusCode, headers) = try await transport.execute(adaptedRequest)
    logger.logResponse(statusCode: statusCode, data: data, error: nil)
    
    return try await handleEmptyResponse(data: data, statusCode: statusCode, headers: headers, originalRequest: adaptedRequest)
  }

  @available(macOS 12.0, iOS 15.0, *)
  public func send<SuccessResponse: Decodable>(request: PortalRequest, medias: [PortalMedia], boundary: String = UUID().uuidString, decoding: SuccessResponse.Type) async throws -> PortalResponse<SuccessResponse> {
    try await send(request: request, medias: medias, boundary: boundary)
  }

  @available(macOS 12.0, iOS 15.0, *)
  @discardableResult
  public func send(request: PortalRequest, medias: [PortalMedia], boundary: String = UUID().uuidString) async throws -> PortalResponse<Void> {
    try Task.checkCancellation()
    var adaptedRequest = interceptor?.adapt(request) ?? request
    adaptedRequest.path = Path(url: baseURL + adaptedRequest.path.url, query: adaptedRequest.path.query)
    if let scheme = adaptedRequest.scheme {
      adaptedRequest.path = Path(url: applyScheme(scheme, to: adaptedRequest.path.url), query: adaptedRequest.path.query)
    }
    let multipartRequest = buildMultipartRequest(from: adaptedRequest, medias: medias, boundary: boundary)
    let (data, statusCode, headers) = try await transport.execute(multipartRequest)
    logger.logResponse(statusCode: statusCode, data: data, error: nil)
    
    return try await handleEmptyResponse(data: data, statusCode: statusCode, headers: headers, originalRequest: multipartRequest)
  }

  @available(macOS 12.0, iOS 15.0, *)
  func send<SuccessResponse: Decodable>(request: PortalRequest) async throws -> PortalResponse<SuccessResponse> {
    try Task.checkCancellation()
    var adaptedRequest = interceptor?.adapt(request) ?? request
    adaptedRequest.path = Path(url: baseURL + adaptedRequest.path.url, query: adaptedRequest.path.query)
    if let scheme = adaptedRequest.scheme {
      adaptedRequest.path = Path(url: applyScheme(scheme, to: adaptedRequest.path.url), query: adaptedRequest.path.query)
    }
    logger.logRequest(adaptedRequest)
    let (data, statusCode, headers) = try await transport.execute(adaptedRequest)
    logger.logResponse(statusCode: statusCode, data: data, error: nil)
    
    return try await handleResponse(data: data, statusCode: statusCode, headers: headers, originalRequest: adaptedRequest)
  }

  @available(macOS 12.0, iOS 15.0, *)
  func send<SuccessResponse: Decodable>(request: PortalRequest, medias: [PortalMedia], boundary: String = UUID().uuidString) async throws -> PortalResponse<SuccessResponse> {
    try Task.checkCancellation()
    var adaptedRequest = interceptor?.adapt(request) ?? request
    adaptedRequest.path = Path(url: baseURL + adaptedRequest.path.url, query: adaptedRequest.path.query)
    if let scheme = adaptedRequest.scheme {
      adaptedRequest.path = Path(url: applyScheme(scheme, to: adaptedRequest.path.url), query: adaptedRequest.path.query)
    }
    let multipartRequest = buildMultipartRequest(from: adaptedRequest, medias: medias, boundary: boundary)
    let (data, statusCode, headers) = try await transport.execute(multipartRequest)
    logger.logResponse(statusCode: statusCode, data: data, error: nil)
    
    return try await handleResponse(data: data, statusCode: statusCode, headers: headers, originalRequest: multipartRequest)
  }
}

// MARK: - Private methods

private extension Portal {
  func applyScheme(_ scheme: PortalRequest.Scheme, to urlString: String) -> String {
    guard urlString.contains("://") else {
      return scheme.rawValue + "://" + urlString
    }
    guard var components = URLComponents(string: urlString) else { return urlString }
    components.scheme = scheme.rawValue
    
    return components.string ?? urlString
  }

  func buildMultipartRequest(from request: PortalRequest, medias: [PortalMedia], boundary: String = UUID().uuidString) -> PortalRequest {
    let body = makeMultipartBody(request: request, medias: medias, boundary: boundary)
    // Wrap raw multipart data as a custom body via a RawDataEncodable shim
    var headers = request.header ?? []
    headers.append(Header(key: .contentType, value: .multipartFormData(boundary: boundary)))
    
    return PortalRequest(
      method: request.method,
      path: request.path,
      header: headers,
      body: Body(data: RawDataBody(data: body), encoding: .json)
    )
  }

  /// This method is used to build the HTTP multipart Body
  func makeMultipartBody(request: PortalRequest, medias: [PortalMedia]?, boundary: String = UUID().uuidString) -> Data {
    func append(_ string: String, to data: inout Data) {
      guard let dataToAppend = string.data(using: .utf8) else {
        assertionFailure("Could not append data!")
        return
      }
      data.append(dataToAppend)
    }

    let lineBreak = "\r\n"
    var body = Data()

    let params = request.body?.data.dictionary
    params?.compactMap { $0 }
      .forEach { param in
        let valueString = String(describing: param.value)
        append("--\(boundary + lineBreak)", to: &body)
        append("Content-Disposition: form-data; name=\"\(param.key)\"\(lineBreak + lineBreak)", to: &body)
        append("\(valueString + lineBreak)", to: &body)
      }

    medias?.compactMap { $0 }
      .forEach { media in
        append("--\(boundary + lineBreak)", to: &body)
        append("Content-Disposition: form-data; name=\"\(media.key)\"; filename=\"\(media.filename)\"\(lineBreak)", to: &body)
        append("Content-Type: \(media.mimeType + lineBreak + lineBreak)", to: &body)
        body.append(media.data)
        append(lineBreak, to: &body)
      }

    append("--\(boundary)--\(lineBreak)", to: &body)

    return body
  }
}

// MARK: - Functions used with async await

@available(macOS 12.0, iOS 15.0, *)
private extension Portal {
  /// This func is the final step to make an HTTP call in async await version using the `data(for: URLRequest)`func.
  func handleResponse<T: Decodable>(data: Data, statusCode: Int, headers: [Header], originalRequest: PortalRequest) async throws -> PortalResponse<T> {
    switch statusCode {
    case 200...299:
      do {
        let value = try JSONDecoder().decode(T.self, from: data)
        return PortalResponse(value: value, statusCode: statusCode, headers: headers, request: originalRequest)
      } catch {
        throw PortalError.decodingFailed(error: error)
      }

    default:
      let error = PortalError.underlying(statusCode: statusCode, data: data)
      logger.logResponse(statusCode: statusCode, data: data, error: error)
      
      return try await shouldRetry(request: originalRequest, error: error)
    }
  }

  func handleEmptyResponse(data: Data, statusCode: Int, headers: [Header], originalRequest: PortalRequest) async throws -> PortalResponse<Void> {
    switch statusCode {
    case 200...299:
      return PortalResponse(value: (), statusCode: statusCode, headers: headers, request: originalRequest)
   
    default:
      let error = PortalError.underlying(statusCode: statusCode, data: data)
      logger.logResponse(statusCode: statusCode, data: data, error: error)
      
      return try await shouldRetryEmpty(request: originalRequest, error: error)
    }
  }

  func shouldRetryEmpty(request: PortalRequest, error: Error) async throws -> PortalResponse<Void> {
    guard let interceptor else { throw error }
    let result = try await interceptor.retry(request, dueTo: error)
    switch result {
    case .retry:
      return try await send(request: request)
    
    case .doNotRetry:
      throw error
    }
  }

  func shouldRetry<T: Decodable>(request: PortalRequest, error: Error) async throws -> PortalResponse<T> {
    guard let interceptor else { throw error }
    let result = try await interceptor.retry(request, dueTo: error)
    switch result {
    case .retry:
      return try await send(request: request)
    
    case .doNotRetry:
      throw error
    }
  }
}

/// Shim to pass raw Data through the Encodable body slot
private struct RawDataBody: Encodable {
    let data: Data
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
}
