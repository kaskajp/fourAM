//
//  Item.swift
//  fourAM
//
//  Created by Jonas on 2025-01-05.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
