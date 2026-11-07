// SDModels.swift
// SwiftData persistent models.
// Schema mirrors db.py's patterns and projects tables.

import Foundation
import SwiftData

// MARK: - SDPattern

@Model
final class SDPattern {
    var id:             UUID    = UUID()
    var name:           String  = ""
    var createdAt:      Date    = Date()
    var sortOrder:      Int     = 0
    var gridW:          Int     = 0
    var gridH:          Int     = 0
    var symmetryGroup:  String  = "d4"
    var fillColor:      String  = "#1a1a2e"
    var bgColor:        String  = "#f5f0e8"
    var fillDensity:    Double  = 0.5
    var gridData:       Data    = Data()   // JSONEncoder([[Bool]])
    var colStripData:   Data?              // JSONEncoder([[Bool]])
    var rowStripData:   Data?
    var cornerData:     Data?
    var stitchData:     Data?              // JSONEncoder([[Stitch]]); nil = all knit
    var kind:           String?            // PatternKind raw value; nil = tile
    var tilingData:     Data?              // JSONEncoder(TilingSettings)
    var thumbnailData:  Data?              // PNG rendered at save time

    init(name: String, gridW: Int, gridH: Int, symmetryGroup: String,
         fillColor: String, bgColor: String, fillDensity: Double,
         gridData: Data, colStripData: Data?, rowStripData: Data?,
         cornerData: Data?, tilingData: Data?) {
        self.id            = UUID()
        self.createdAt     = Date()
        self.name          = name
        self.gridW         = gridW
        self.gridH         = gridH
        self.symmetryGroup = symmetryGroup
        self.fillColor     = fillColor
        self.bgColor       = bgColor
        self.fillDensity   = fillDensity
        self.gridData      = gridData
        self.colStripData  = colStripData
        self.rowStripData  = rowStripData
        self.cornerData    = cornerData
        self.tilingData    = tilingData
    }
}

// MARK: - SDProject

@Model
final class SDProject {
    var id:        UUID   = UUID()
    var name:      String = ""
    var createdAt: Date   = Date()
    var sortOrder: Int    = 0
    var data:      Data   = Data()   // JSONEncoder(PatternSnapshot)

    var thumbnailData: Data? = nil

    init(name: String, data: Data) {
        self.id        = UUID()
        self.createdAt = Date()
        self.name      = name
        self.data      = data
    }
}
