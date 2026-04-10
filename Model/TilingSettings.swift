// TilingSettings.swift

import Foundation

struct TilingSettings: Codable, Equatable {
    var hRepeat:   Bool       = false
    var vRepeat:   Bool       = false
    var stripWidth: Int       = 1
    var hType:     RepeatType = .translation
    var vType:     RepeatType = .translation
    var rowOffset: Int        = 0
    var colOffset: Int        = 0

    // Preview-only (not stored in pattern; stored in project)
    var nCopies:        Int     = 3
    var previewCellSize: Double = 8
}
