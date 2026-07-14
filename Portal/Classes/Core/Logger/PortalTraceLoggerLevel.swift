//
//  PortalLoggerLogLevel.swift
//  Portal
//
//  Copyright © 2022 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

/// Controls how much network activity `Portal` prints to the console.
public enum PortalTraceLoggerLevel {
  /// Logging disabled.
  case none
  /// Prints full request and response details including body.
  case debug
  /// Prints status codes only, without body content.
  case release
}
