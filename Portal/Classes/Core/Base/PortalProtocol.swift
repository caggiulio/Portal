//
//  PortalProtocol.swift
//  Portal
//
//  Copyright © 2026 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

/// Describes the public interface for making HTTP requests.
///
/// Use `send(request:decoding:)` to decode a response body, or `send(request:)` when no response body is expected.
/// Multipart variants accept an array of `PortalMedia` objects and an optional boundary string.
public protocol PortalProtocol {
  // MARK: - Plain requests

  /// Performs an HTTP request and decodes the response body into the specified type.
  /// - Parameters:
  ///   - request: The `PortalRequest` describing the HTTP call.
  ///   - decoding: The `Decodable` type to decode the response body into.
  /// - Returns: A decoded instance of `SuccessResponse`.
  @available(macOS 12.0, iOS 15.0, *)
  func send<SuccessResponse: Decodable>(request: PortalRequest, decoding: SuccessResponse.Type) async throws -> PortalResponse<SuccessResponse>

  /// Performs an HTTP request, ignoring the response body.
  /// - Parameter request: The `PortalRequest` describing the HTTP call.
  /// - Returns: A `PortalResponse<Void>` containing status code, headers, and the adapted request.
  @available(macOS 12.0, iOS 15.0, *)
  @discardableResult
  func send(request: PortalRequest) async throws -> PortalResponse<Void>

  // MARK: - Multipart requests

  /// Performs a multipart HTTP request and decodes the response body into the specified type.
  /// - Parameters:
  ///   - request: The `PortalRequest` describing the HTTP call.
  ///   - medias: Media attachments to include in the multipart body.
  ///   - boundary: The multipart boundary string.
  ///   - decoding: The `Decodable` type to decode the response body into.
  /// - Returns: A `PortalResponse` wrapping the decoded `SuccessResponse`.
  @available(macOS 12.0, iOS 15.0, *)
  func send<SuccessResponse: Decodable>(request: PortalRequest, medias: [PortalMedia], boundary: String, decoding: SuccessResponse.Type) async throws -> PortalResponse<SuccessResponse>

  /// Performs a multipart HTTP request, ignoring the response body.
  /// - Parameters:
  ///   - request: The `PortalRequest` describing the HTTP call.
  ///   - medias: Media attachments to include in the multipart body.
  ///   - boundary: The multipart boundary string.
  /// - Returns: A `PortalResponse<Void>` containing status code, headers, and the adapted request.
  @available(macOS 12.0, iOS 15.0, *)
  @discardableResult
  func send(request: PortalRequest, medias: [PortalMedia], boundary: String) async throws -> PortalResponse<Void>
}
