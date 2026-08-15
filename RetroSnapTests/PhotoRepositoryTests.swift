//
//  PhotoRepositoryTests.swift
//  RetroSnapTests
//
//  cameraID の保存と、既存ユーザーのストアの移行の保証。
//  - 撮影に使ったカメラが写真ごとに残ること
//  - **cameraID を足す前に作られたストアを開いても写真が1枚も消えないこと**
//    （ここが壊れると既存ユーザーのアルバムが飛ぶので、機械で見張る）
//

import CoreData
import XCTest
@testable import RetroSnap

final class PhotoRepositoryTests: XCTestCase {

    private var repository: PhotoRepository!

    override func setUpWithError() throws {
        repository = PhotoRepository(inMemory: true)
    }

    override func tearDownWithError() throws {
        repository = nil
    }

    // MARK: - cameraID の保存

    func testInsertKeepsTheCameraUsedForTheShot() throws {
        let camera = CameraCatalog.all.last!
        repository.insert(name: "shot", path: URL(fileURLWithPath: "/tmp/shot.png"), cameraID: camera.id)

        let photos = repository.fetchAllPhotos()
        XCTAssertEqual(photos.count, 1)
        XCTAssertEqual(photos.first?.cameraID, camera.id)
    }

    func testInsertWithoutCameraKeepsItUnknown() throws {
        repository.insert(name: "shot", path: URL(fileURLWithPath: "/tmp/shot.png"))

        let photos = repository.fetchAllPhotos()
        XCTAssertEqual(photos.count, 1)
        // 「不明」を既定カメラで埋めない。埋めると事実と違う記録になる
        XCTAssertNil(photos.first?.cameraID)
    }

    func testEachPhotoKeepsItsOwnCamera() throws {
        for (index, spec) in CameraCatalog.all.enumerated() {
            repository.insert(
                name: spec.id.rawValue,
                path: URL(fileURLWithPath: "/tmp/\(index).png"),
                cameraID: spec.id
            )
        }

        let photos = repository.fetchAllPhotos()
        XCTAssertEqual(photos.count, CameraCatalog.all.count)
        for photo in photos {
            XCTAssertEqual(photo.cameraID?.rawValue, photo.name)
        }
    }

    // MARK: - モデル

    func testCurrentModelHasCameraID() throws {
        let entity = try XCTUnwrap(currentModel().entitiesByName["PhotoData"])
        let attribute = try XCTUnwrap(entity.attributesByName["cameraID"])

        XCTAssertEqual(attribute.attributeType, .stringAttributeType)
        // nil 許容にしてある。既存の写真は「どのカメラでもない」ので埋められない
        XCTAssertTrue(attribute.isOptional)
    }

    // MARK: - 軽量マイグレーション

    /// cameraID を足す前のモデル（Photo）で作ったストアを、今のモデルで開けること。
    /// 写真が消えず、既存レコードの cameraID が nil になることまで見る。
    func testStoreFromPreviousModelVersionMigratesWithoutLosingPhotos() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-\(UUID().uuidString).sqlite")
        addTeardownBlock { try? FileManager.default.removeItem(at: storeURL) }

        // 1. 旧モデルでストアを作り、写真を1枚入れる
        let legacyModel = try previousModel()
        let legacyCoordinator = NSPersistentStoreCoordinator(managedObjectModel: legacyModel)
        try legacyCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        )
        let legacyContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        legacyContext.persistentStoreCoordinator = legacyCoordinator

        let legacyPhoto = NSEntityDescription.insertNewObject(forEntityName: "PhotoData", into: legacyContext)
        let legacyID = UUID()
        legacyPhoto.setValue(legacyID, forKey: "id")
        legacyPhoto.setValue("old", forKey: "name")
        legacyPhoto.setValue(URL(fileURLWithPath: "/tmp/old.png"), forKey: "path")
        legacyPhoto.setValue(Date(), forKey: "createdAt")
        legacyPhoto.setValue(Date(), forKey: "updatedAt")
        try legacyContext.save()

        // 旧モデルには cameraID が無いことを確かめておく（この前提が崩れるとテストの意味が無い）
        XCTAssertNil(legacyModel.entitiesByName["PhotoData"]?.attributesByName["cameraID"])

        for store in legacyCoordinator.persistentStores {
            try legacyCoordinator.remove(store)
        }

        // 2. 今のモデルで同じストアを開く（アプリと同じ設定＝推論マッピングでの自動移行）
        let container = try NSPersistentContainer(name: "PhotoData", managedObjectModel: currentModel())
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        XCTAssertNil(loadError, "既存ストアの移行に失敗した: \(String(describing: loadError))")

        // 3. 写真が残っていること
        let request = NSFetchRequest<NSManagedObject>(entityName: "PhotoData")
        let migrated = try container.viewContext.fetch(request)
        XCTAssertEqual(migrated.count, 1, "移行で写真が消えた")
        XCTAssertEqual(migrated.first?.value(forKey: "id") as? UUID, legacyID)
        XCTAssertEqual(migrated.first?.value(forKey: "name") as? String, "old")
        XCTAssertNil(migrated.first?.value(forKey: "cameraID"), "既存レコードは「不明」のまま残す")
    }

    // MARK: - モデルの読み出し

    private func modelBundle() throws -> URL {
        let bundle = Bundle(for: PhotoRepository.self)
        return try XCTUnwrap(
            bundle.url(forResource: "PhotoData", withExtension: "momd"),
            "PhotoData.momd が見つからない"
        )
    }

    private func currentModel() throws -> NSManagedObjectModel {
        try XCTUnwrap(NSManagedObjectModel(contentsOf: modelBundle()), "現行モデルを読めない")
    }

    /// cameraID を足す前のモデル。バンドルには全バージョンの .mom が入る。
    private func previousModel() throws -> NSManagedObjectModel {
        let url = try modelBundle().appendingPathComponent("Photo.mom")
        return try XCTUnwrap(NSManagedObjectModel(contentsOf: url), "旧モデル Photo.mom を読めない")
    }
}
