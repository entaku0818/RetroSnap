//
//  PhotoRepository.swift
//  RetroSnap
//
//  Created by 遠藤拓弥 on 8.10.2023.
//

import Foundation

import Foundation
import CoreData

class PhotoRepository: NSObject {

    static let shared = PhotoRepository()

    let container: NSPersistentContainer
    var managedContext: NSManagedObjectContext
    var entity: NSEntityDescription?

    let entityName: String = "PhotoData"

    /// - Parameter inMemory: true でディスクに触らない一時ストアを使う（テスト用）。
    init(inMemory: Bool = false) {

        container = NSPersistentContainer(name: entityName)

        if inMemory {
            container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))]
        }

        // モデルは版管理されている（Photo → Photo 2 で cameraID を追加）。
        // 既存ユーザーのストアは Photo のままなので、開くときに必ず移行が要る。
        // 属性を1つ足しただけなので推論マッピングで足り、写真は1枚も失われない。
        // 既定値だが、消えると既存データが開けなくなる設定なので明示しておく。
        for description in container.persistentStoreDescriptions {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        container.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true

        self.managedContext = container.viewContext
        if let localEntity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext) {
            self.entity = localEntity
        }
    }

    /// - Parameter cameraID: 撮影に使ったカメラ。
    ///   nil を許すのは、**カメラ切替より前に撮られた写真がどのカメラでもないから**。
    ///   移行時に既存レコードへ `plain70` を書き込む案は採らなかった。当時の現像は
    ///   今の plain70 とは別物で、後から plain70 だったことにするのは事実と違う記録になる。
    ///   「不明」は nil のまま残し、表示側が必要なときだけ `CameraCatalog.camera(forSlug:)` で
    ///   既定へ寄せる（＝寄せるかどうかを読み手が選べる）。
    func insert(name: String, path: URL, cameraID: CameraID? = nil) {
        if let photo = NSManagedObject(entity: self.entity!, insertInto: managedContext) as? PhotoData {

            photo.id = UUID()
            photo.name = name
            photo.path = path
            photo.cameraID = cameraID?.rawValue
            photo.createdAt = Date()
            photo.updatedAt = Date()


            do {
                try managedContext.save()
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }

    func fetchAllPhotos() -> [Photos.Photo] {
        let fetchRequest: NSFetchRequest<PhotoData> = PhotoData.fetchRequest()

        // 作成日順にソートするためのソート記述子を作成
        let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            let coreDataPhotos = try managedContext.fetch(fetchRequest)
            return coreDataPhotos.compactMap { Photos.Photo(from: $0) }
        } catch let error {
            print(error.localizedDescription)
            return []
        }
    }
}

extension Photos.Photo {
    init?(from coreDataPhoto: PhotoData) {
        guard let id = coreDataPhoto.id,
              let name = coreDataPhoto.name,
              let imageURL = coreDataPhoto.path else {
            return nil
        }
        self.id = id
        self.name = name
        self.imageURL = imageURL
        // カメラ切替より前の写真は nil。どのカメラで撮ったか分からないことを、そのまま持ち上げる。
        self.cameraID = coreDataPhoto.cameraID.map(CameraID.init(_:))
    }
}
