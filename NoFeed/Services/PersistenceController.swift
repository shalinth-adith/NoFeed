//
//  PersistenceController.swift
//  NoFeed
//
//  Core Data stack. Uses NSPersistentCloudKitContainer with a CloudKit-shaped
//  schema, but leaves `cloudKitContainerOptions` unset — so the store is local
//  for now (no iCloud capability needed). Phase 4 enables sync by setting the
//  container options; no migration required.
//
//  The store lives in the App Group so extensions can read it if needed.
//

import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    /// Load the model exactly once so repeated container inits (e.g. tests) don't
    /// register duplicate NSEntityDescriptions for the same model.
    private static let model: NSManagedObjectModel = {
        // A missing model is a broken build, not a runtime condition. An empty
        // model used to stand in, which crashed later on the first entity
        // created, far from the cause.
        guard let url = Bundle.main.url(forResource: "Zenly", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Zenly.momd is missing from the app bundle")
        }
        return model
    }()

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Zenly", managedObjectModel: Self.model)

        let description = container.persistentStoreDescriptions.first ?? NSPersistentStoreDescription()
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else {
            description.url = AppGroup.containerURL.appendingPathComponent("Zenly.sqlite")
        }

        // CloudKit-ready but local: no cloudKitContainerOptions => no sync yet.
        description.cloudKitContainerOptions = nil
        // Lightweight migration for additive model changes (e.g. blockAllApps).
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        // Keep history so a future CloudKit mirror (Phase 4) can replay changes.
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber,
                              forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }

        if let loadError {
            // Don't crash, and don't run without a store: every save would then
            // fail and be lost unseen. Report it, and fall back to an in-memory
            // store so the app still works for this launch.
            StoreHealth.shared.storeUnavailable(loadError)
            let fallback = NSPersistentStoreDescription()
            fallback.url = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions = [fallback]
            container.loadPersistentStores { _, error in
                if let error { StoreHealth.shared.storeUnavailable(error) }
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Save the view context if it has pending changes.
    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            StoreHealth.shared.saveFailed(error, in: "PersistenceController")
        }
    }
}
