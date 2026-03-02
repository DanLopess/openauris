# Model Storage Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix model download progress reporting and improve model deletion reliability in OpenAuris

**Architecture:**
- Fix download progress to only show real network progress  
- Make model deletion transactional to prevent bad states
- Add proper error handling and validation

**Tech Stack:** Swift, SwiftData, WhisperKit, FileManager

---

## Issues to Address

### Issue 1: Download Progress Shows False Progress
**Problem:** Progress bar shows 30%+ before actual network download starts
**Root Cause:** WhisperKit.download callback reports cached/buffered progress
**Solution:** Only show progress > 0 after confirming real network activity

### Issue 2: Model Deletion Can Fail Silently  
**Problem:** File deletion and database updates can fail independently
**Root Cause:** No transactional safety, silent error handling with try?
**Solution:** Make deletion atomic, add proper error handling and validation

---

## Implementation Plan

### Task 1: Fix Download Progress Reporting

**Files:**
- Modify: `openauris/Services/Models/WhisperModelManager.swift:185-195`

**Step 1: Update performInstall method to track real network progress**

```swift
// Replace the download progress tracking in performInstall method
downloadProgress[model.id] = 0

// Track download start and network activity confirmation  
let downloadStartTime = Date()
var hasNetworkActivityStarted = false

_ = try await WhisperKit.download(variant: model.id) { [weak self] progress in
    Task { @MainActor [weak self] in
        guard let self = self else { return }
        
        // Only show progress if at 0% or network activity confirmed
        if progress.fractionCompleted == 0 {
            // Always allow 0% progress
            self.downloadProgress[model.id] = 0
        } else if hasNetworkActivityStarted {
            // Show progress if network activity confirmed
            self.downloadProgress[model.id] = progress.fractionCompleted
        } else {
            // Check if this is real progress (not cached/buffered)
            let elapsed = Date().timeIntervalSince(downloadStartTime)
            if elapsed > 1.0 { // Only consider real after 1 second
                hasNetworkActivityStarted = true
                self.downloadProgress[model.id] = progress.fractionCompleted
            } else {
                // Keep at 0% until network activity confirmed
                self.downloadProgress[model.id] = 0
            }
        }
    }
}
```

**Step 2: Test download progress behavior**
- Build and run the app
- Start a model download  
- Verify progress stays at 0% until actual network activity begins
- Verify progress then updates correctly

---

### Task 2: Improve Model Deletion Reliability

**Files:**
- Modify: `openauris/Services/Models/WhisperModelManager.swift:211-216`
- Modify: `openauris/Services/Models/WhisperModelManager.swift:237-261`

**Step 1: Add proper error handling to file deletion**

```swift
private func removeCachedArtifacts(for modelID: String) throws {
    let cachedFolders = cachedModelFolders(for: modelID)
    
    var fileDeletionErrors: [Error] = []
    
    for url in cachedFolders {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            fileDeletionErrors.append(error)
        }
    }
    
    if !fileDeletionErrors.isEmpty {
        throw WhisperModelManagerError.modelDeletionFailed(
            modelID: modelID,
            underlyingErrors: fileDeletionErrors
        )
    }
}
```

**Step 2: Add new error cases**

```swift
// Add to WhisperModelManagerError enum
case modelDeletionFailed(modelID: String, underlyingErrors: [Error])
case cannotDeleteDefaultModel  
case modelDeletionValidationFailed(modelID: String)

// Add to errorDescription
case .modelDeletionFailed(let modelID, _):
    return "Failed to delete model '\{modelID}'. Some files may remain."
case .cannotDeleteDefaultModel:
    return "Cannot delete the default model. Set another model as default first."
case .modelDeletionValidationFailed(let modelID):
    return "Model '\{modelID}' deletion validation failed."
```

**Step 3: Make deletion transactional**

```swift
func remove(modelID: String) throws {
    guard modelID != defaultModelID else {
        throw WhisperModelManagerError.cannotDeleteDefaultModel
    }
    
    guard let descriptor = models.first(where: { $0.id == modelID }) else {
        throw WhisperModelManagerError.unknownModel(modelID)
    }
    
    // Step 1: Delete files
    try removeCachedArtifacts(for: modelID)
    
    // Step 2: Update database  
    try repository.upsertModel(
        modelID: modelID,
        displayName: descriptor.displayName,
        sizeBytes: descriptor.estimatedSizeBytes,
        state: "not_installed",
        isDefault: false,
        installedAt: nil,
        lastUsedAt: nil,
        overwriteInstalledAt: true,
        overwriteLastUsedAt: true
    )
    
    // Step 3: Update in-memory state (only if everything succeeded)
    installedModelIDs.remove(modelID)
    downloadProgress.removeValue(forKey: modelID)
    downloadStateByModelID[modelID] = "not_installed"
}
```

---

### Task 3: Add Deletion Validation

**Files:**
- Add method in `openauris/Services/Models/WhisperModelManager.swift`

**Step 1: Add validation method**

```swift
func validateModelDeletion(_ modelID: String) -> Bool {
    if installedModelIDs.contains(modelID) { return false }
    
    do {
        let models = try repository.fetchModels()
        if let model = models.first(where: { $0.modelID == modelID }), 
           model.downloadState == "installed" {
            return false
        }
    } catch { return false }
    
    if hasValidCachedArtifacts(for: modelID) { return false }
    
    return true
}
```

**Step 2: Add validation to remove method**

```swift
// At end of remove method after updating in-memory state:
if !validateModelDeletion(modelID) {
    throw WhisperModelManagerError.modelDeletionValidationFailed(modelID: modelID)
}
```

---

### Task 4: Update UI Error Handling

**Files:**
- Modify: `openauris/UI/Dashboard/ModelsDashboardView.swift:34`

**Step 1: Update remove button action**

```swift
Button("Remove", role: .destructive) {
    guard let pendingRemoveModelID else { return }
    do {
        try container.modelManager.remove(modelID: pendingRemoveModelID)
        self.pendingRemoveModelID = nil
    } catch {
        container.startupErrorMessage = error.localizedDescription
    }
}
```

---

## Testing Plan

### Test 1: Download Progress Accuracy
1. Start model download
2. Monitor network traffic vs progress bar
3. Verify 0% until real network activity
4. Verify accurate progress reporting

### Test 2: Successful Deletion
1. Install non-default model
2. Delete model
3. Verify files removed
4. Verify database updated
5. Verify UI updated

### Test 3: Failed Deletion (Filesystem)
1. Mock FileManager errors
2. Attempt deletion
3. Verify error thrown
4. Verify in-memory state unchanged

### Test 4: Failed Deletion (Database)
1. Mock repository errors  
2. Attempt deletion
3. Verify error thrown
4. Verify state consistency

### Test 5: Default Model Protection
1. Attempt delete default model
2. Verify error thrown
3. Verify model not deleted

---

## Execution Approach

**Plan ready in:** `docs/plans/2026-02-25-model-storage-fixes.md`

**Execution options:**
1. **Subagent-Driven** - Step-by-step with immediate review
2. **Batch Execution** - Grouped tasks with checkpoints

**Recommend:** Subagent-Driven for critical storage fixes