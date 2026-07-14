//
//  PortalError.swift
//  Portal
//
//  Copyright © 2022 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

/// Errors thrown by the Portal layer.
public enum PortalError: Error {
  /// The URL could not be constructed from the request path.
  case invalidUrl
  /// The response was not a valid HTTP response.
  case invalidHTTPResponse
  /// JSON decoding of the response body failed.
  case decodingFailed(error: Error)
  /// A generic, unclassified error.
  case other(error: Error)
  /// A non-2xx HTTP response. Carries the status code and raw response body.
  case underlying(statusCode: Int, data: Data?)
}
