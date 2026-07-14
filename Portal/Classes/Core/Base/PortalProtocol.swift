//
//  PortalProtocol.swift
//  Portal
//
//  Copyright © 2022 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

public protocol PortalProtocol {
  // MARK: - iOS > 15 Protocols

  @available(macOS 12.0, iOS 15.0, *)
  /// This is the func to use to make an HTTP call in async/await version.
  /// - Parameter request: The `PortalRequest` object with HTTP information request.
  /// - Returns `SuccessResponse` using `async await` pattern. `SuccessResponse` is a Decodable to decode in HTTP response.
  func send<SuccessResponse: Decodable>(request: PortalRequest) async throws -> SuccessResponse

  /// This is the func to use to make an HTTP multipart call in async/await version.
  /// - Parameters:
  ///   - request: The `PortalRequest` object with HTTP information request.
  ///   - medias: Array of `PortalMedia` object with media informations to upload.
  ///   - boundary: The boundary of HTTP multipart request.
  /// - Returns `SuccessResponse` using `async await` pattern. `SuccessResponse` is a Decodable to decode in HTTP response.
  @available(macOS 12.0, iOS 15.0, *)
  func send<SuccessResponse: Decodable>(request: PortalRequest, medias: [PortalMedia], boundary: String) async throws -> SuccessResponse
}
