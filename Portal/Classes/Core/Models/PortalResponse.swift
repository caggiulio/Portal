//
//  PortalResponse.swift
//  Portal
//
//  Copyright © 2026 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

/// Wraps a decoded response value together with HTTP metadata.
public struct PortalResponse<T> {

    /// The decoded response body.
    public let value: T

    /// The HTTP status code.
    public let statusCode: Int

    /// The HTTP response headers.
    public let headers: [Header]

    /// The adapted request that produced this response.
    public let request: PortalRequest
}
