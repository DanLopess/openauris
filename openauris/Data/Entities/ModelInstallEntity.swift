import Foundation
import SwiftData

@Model
final class ModelInstallEntity {
    @Attribute(.unique) var modelID: String
    var displayName: String
    var sizeBytes: Int64
    var installedAt: Date?
    var lastUsedAt: Date?
    var isDefault: Bool
    var downloadState: String
    var checksum: String

    init(
        modelID: String,
        displayName: String,
        sizeBytes: Int64,
        installedAt: Date? = nil,
        lastUsedAt: Date? = nil,
        isDefault: Bool,
        downloadState: String,
        checksum: String
    ) {
        self.modelID = modelID
        self.displayName = displayName
        self.sizeBytes = sizeBytes
        self.installedAt = installedAt
        self.lastUsedAt = lastUsedAt
        self.isDefault = isDefault
        self.downloadState = downloadState
        self.checksum = checksum
    }
}
