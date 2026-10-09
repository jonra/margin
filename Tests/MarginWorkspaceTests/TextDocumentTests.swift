import Foundation
import Testing
@testable import MarginWorkspace

private func tempFile(_ content: String) throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("f.txt")
    try content.write(to: url, atomically: true, encoding: .utf8)
    return url
}

private func disk(_ url: URL) throws -> String { try String(contentsOf: url, encoding: .utf8) }

@Test func cleanDocumentReloadsSilentlyOnExternalChange() throws {
    let url = try tempFile("one")
    var doc = try TextDocument(url: url)
    try "two".write(to: url, atomically: true, encoding: .utf8)
    doc.diskChanged()
    #expect(doc.text == "two" && !doc.isDirty && doc.conflict == nil)
}

@Test func dirtyDocumentRefusesToOverwriteExternalChange() throws {
    let url = try tempFile("one")
    var doc = try TextDocument(url: url)
    doc.text = "mine"
    try "agent".write(to: url, atomically: true, encoding: .utf8)
    #expect(try doc.saveIfSafe() == false)
    #expect(doc.conflict == .modifiedOnDisk)
    #expect(try disk(url) == "agent")
    #expect(doc.text == "mine" && doc.isDirty)
    doc.diskChanged()
    #expect(doc.conflict == .modifiedOnDisk)
}

@Test func externalDeleteWhileDirtyIsNotRecreated() throws {
    let url = try tempFile("one")
    var doc = try TextDocument(url: url)
    doc.text = "mine"
    try FileManager.default.removeItem(at: url)
    #expect(try doc.saveIfSafe() == false)
    #expect(doc.conflict == .deletedOnDisk)
    #expect(!FileManager.default.fileExists(atPath: url.path))
}

@Test func cleanDocumentDeletedOnDiskFlagsConflictWithoutRecreating() throws {
    let url = try tempFile("one")
    var doc = try TextDocument(url: url)
    try FileManager.default.removeItem(at: url)
    doc.diskChanged()
    #expect(doc.conflict == .deletedOnDisk)
    #expect(!FileManager.default.fileExists(atPath: url.path))
}

@Test func keepMineThenSaveWritesUserText() throws {
    let url = try tempFile("one")
    var doc = try TextDocument(url: url)
    doc.text = "mine"
    try "agent".write(to: url, atomically: true, encoding: .utf8)
    _ = try doc.saveIfSafe()
    doc.keepMine()
    #expect(doc.conflict == nil && doc.isDirty)
    #expect(try doc.saveIfSafe() == true)
    #expect(try disk(url) == "mine" && !doc.isDirty)
}

@Test func keepMineAfterDeleteRecreatesOnSave() throws {
    let url = try tempFile("one")
    var doc = try TextDocument(url: url)
    doc.text = "mine"
    try FileManager.default.removeItem(at: url)
    _ = try doc.saveIfSafe()
    doc.keepMine()
    #expect(try doc.saveIfSafe() == true)
    #expect(try disk(url) == "mine")
}

@Test func reloadFailureThrowsAndKeepsConflict() throws {
    let url = try tempFile("one")
    var doc = try TextDocument(url: url)
    doc.text = "mine"
    try FileManager.default.removeItem(at: url)
    _ = try doc.saveIfSafe()
    #expect(throws: (any Error).self) { try doc.reloadFromDisk() }
    #expect(doc.conflict == .deletedOnDisk && doc.text == "mine")
}

@Test func reloadFromDiskResolvesConflict() throws {
    let url = try tempFile("one")
    var doc = try TextDocument(url: url)
    doc.text = "mine"
    try "agent".write(to: url, atomically: true, encoding: .utf8)
    _ = try doc.saveIfSafe()
    try doc.reloadFromDisk()
    #expect(doc.text == "agent" && !doc.isDirty && doc.conflict == nil)
}

@Test func plainDirtySaveWritesAndBecomesClean() throws {
    let url = try tempFile("one")
    var doc = try TextDocument(url: url)
    doc.text = "mine"
    #expect(doc.isDirty)
    #expect(try doc.saveIfSafe() == true)
    #expect(try disk(url) == "mine" && !doc.isDirty)
}

@Test func ownSaveEchoDoesNotFlagConflict() throws {
    let url = try tempFile("one")
    var doc = try TextDocument(url: url)
    doc.text = "mine"
    _ = try doc.saveIfSafe()
    doc.diskChanged()
    #expect(doc.conflict == nil && doc.text == "mine" && !doc.isDirty)
}

@Test func explicitSaveOverwritesAndClearsConflict() throws {
    let url = try tempFile("one")
    var doc = try TextDocument(url: url)
    doc.text = "mine"
    try "agent".write(to: url, atomically: true, encoding: .utf8)
    _ = try doc.saveIfSafe()
    try doc.save()
    #expect(try disk(url) == "mine" && doc.conflict == nil)
}
