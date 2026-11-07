// TilingSettings.swift

import Foundation

struct TilingSettings: Codable, Equatable {
    var hRepeat:   Bool       = false
    var vRepeat:   Bool       = false
    /// Copies side by side: `.reflection` reflects across a vertical axis.
    var horizontalRepeatType: RepeatType = .translation
    /// Copies stacked: `.reflection` reflects across a horizontal axis.
    var verticalRepeatType:   RepeatType = .translation
    var stripWidth: Int       = 1
    var stripReflectsAcrossVerticalAxis:   Bool = false
    var stripReflectsAcrossHorizontalAxis: Bool = false
    var rowOffset: Int        = 0
    var colOffset: Int        = 0

    // Preview-only (not stored in pattern; stored in project)
    var nCopies:        Int     = 3
    var previewCellSize: Double = 8

    /// Stored key names predate naming reflections by axis; keep them so saved Projects load.
    private enum CodingKeys: String, CodingKey {
        case hRepeat, vRepeat, stripWidth, rowOffset, colOffset, nCopies, previewCellSize
        case horizontalRepeatType              = "hType"
        case verticalRepeatType                = "vType"
        case stripReflectsAcrossVerticalAxis   = "stripHReflect"
        case stripReflectsAcrossHorizontalAxis = "stripVReflect"
    }
}
