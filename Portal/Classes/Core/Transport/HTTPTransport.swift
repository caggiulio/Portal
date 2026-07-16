import Foundation

/// Abstracts the underlying HTTP mechanism (URLSession, NIO, mock, etc.).
/// Implement this protocol to provide a custom transport to `Portal`.
public protocol HTTPTransport {
    /// Executes `request` and returns the raw response body, HTTP status code, and response headers.
    func execute(_ request: PortalRequest) async throws -> (Data, Int, [Header])
}
