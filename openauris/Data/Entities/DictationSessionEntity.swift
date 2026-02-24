import Foundation
import SwiftData

@Model
final class DictationSessionEntity {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date
    var modeRawValue: String
    var partialPreview: String
    var finalText: String
    var languageCode: String
    var modelID: String
    var audioDurationSec: Double
    var wordCount: Int
    var wpm: Double
    var insertionMethod: String
    var targetBundleID: String
    var isDeleted: Bool

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        modeRawValue: String,
        partialPreview: String,
        finalText: String,
        languageCode: String,
        modelID: String,
        audioDurationSec: Double,
        wordCount: Int,
        wpm: Double,
        insertionMethod: String,
        targetBundleID: String,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.modeRawValue = modeRawValue
        self.partialPreview = partialPreview
        self.finalText = finalText
        self.languageCode = languageCode
        self.modelID = modelID
        self.audioDurationSec = audioDurationSec
        self.wordCount = wordCount
        self.wpm = wpm
        self.insertionMethod = insertionMethod
        self.targetBundleID = targetBundleID
        self.isDeleted = isDeleted
    }
}
