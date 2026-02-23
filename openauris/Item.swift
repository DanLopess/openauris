//
//  Item.swift
//  openauris
//
//  Created by Daniel Lopes on 23.02.2026.
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
