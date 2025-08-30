//
//  Loggers.swift
//
//
//  Created by Bryan Montz on 12/10/23.
//

import Foundation
import OSLog

enum Loggers {
    private static let subsystem = "NostrSDK"
    @available(iOS 14.0.0, *)
    static let keypairs = Logger(subsystem: Loggers.subsystem, category: "Keypairs")
    @available(iOS 14.0.0, *)
    static let relayDecoding = Logger(subsystem: Loggers.subsystem, category: "RelayDecoding")
}
