//
//  PortalInterceptorProtocol.swift
//  Portal
//
//  Copyright © 2026 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

/// Allows mutation of a request before it is sent.
public protocol RequestAdapter {
    /// Returns a (possibly modified) copy of `request`.
    func adapt(_ request: PortalRequest) -> PortalRequest
}

/// Decides whether a failed request should be retried.
public protocol RetryAdapter {
    /// Called after a request fails. Return `.retry` to re-send, `.doNotRetry` to propagate the error.
    func retry(_ request: PortalRequest, dueTo error: Error) async throws -> RetryResult
}

/// Combines request adaptation and retry logic. Conform to this to plug custom auth, logging, or retry policies into `Portal`.
public protocol PortalInterceptorProtocol: RequestAdapter, RetryAdapter {}

public extension PortalInterceptorProtocol {
    func adapt(_ request: PortalRequest) -> PortalRequest {
        return request
    }

    func retry(_ request: PortalRequest, dueTo error: Error) async throws -> RetryResult {
        return .doNotRetry
    }
}

/// The outcome of a retry decision.
public enum RetryResult {
    /// Re-send the original request.
    case retry
    /// Propagate the error without retrying.
    case doNotRetry
}
