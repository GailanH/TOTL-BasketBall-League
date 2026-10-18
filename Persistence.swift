//
//  Persistence.swift
//  Project_Comp_B
//
//  Created by Gailan Hart on 6/20/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    /// Loaded once and shared. Creating a second copy of the same model (e.g. in unit tests)
    /// makes Core Data unsure which entity a `Player(context:)` refers to.
    static let model: NSManagedObjectModel = {
        let bundle = Bundle(for: Player.self)
        guard let url = bundle.url(forResource: "Project_Comp_B", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Couldn't load the Project_Comp_B Core Data model.")
        }
        return model
    }()

    /// In-memory store for SwiftUI previews. Empty; previews create what they need.
    @MainActor
    static let preview = PersistenceController(inMemory: true)

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Project_Comp_B", managedObjectModel: Self.model)
        if let description = container.persistentStoreDescriptions.first {
            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
            // The model is versioned (Project_Comp_B.xcdatamodeld). Adding a version with new
            // optional/defaulted attributes or new entities migrates existing data automatically.
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        container.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error as NSError? {
                // Most likely cause during development: the on-device store was created by an
                // unversioned model edit that can't be migrated. Deleting the app from the
                // Simulator resets it. Needs real handling before production.
                fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
