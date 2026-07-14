import Foundation

/// Abstracts the underlying HTTP mechanism (URLSession, NIO, mock, etc.).
/// Implement this protocol to provide a custom transport to `Portal`.
public protocol HTTPTransport {
    /// Executes `request` and returns the raw response body and HTTP status code.
    func execute(_ request: PortalRequest) async throws -> (Data, Int)
}
