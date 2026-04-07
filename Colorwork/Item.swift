//
//  Item.swift
//  Colorwork
//
//  Created by Emily Stein on 4/7/26.
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
