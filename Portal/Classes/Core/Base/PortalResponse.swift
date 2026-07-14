//
//  PortalResponse.swift
//  Portal
//
//  Created by Nunzio Giulio Caggegi on 7/14/26.
//

import Foundation

public protocol PortalResponse: Decodable {
  static func decode(from data: Data) throws -> Self
}

extension PortalResponse {
  public static func decode(from data: Data) throws -> Self {
    try JSONDecoder().decode(Self.self, from: data)
  }
}

public struct PortalEmptyResponse: PortalResponse {
  public init() {}
  
  public static func decode(from data: Data) throws -> PortalEmptyResponse {
    PortalEmptyResponse()
  }
}
