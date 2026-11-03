import Foundation
import os

/// Failures that the user can't see go here, so Console shows why an alert stayed silent.
let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "fifteenfive", category: "app")
