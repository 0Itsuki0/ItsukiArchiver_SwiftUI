//
//  ZipManager.swift
//  ItsukiZipper
//
//  Created by Itsuki on 2024/12/26.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let zipDocumentType = UTType(exportedAs: "itsuki.enjoy.ItsukiZipper.zipDocumentType")
}

struct ZipDocument: FileDocument {
    var data: Data = Data()

    init(_ data: Data) {
        self.data = data
    }

    static var readableContentTypes: [UTType] = [.zipDocumentType]
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            self.data = data
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
    
}


private extension URL {
    var isDirectory: Bool {
       (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}


class ZipManager {
    enum ZipError: Error {
        case sourceNotProvided
        case accessDenied
        case creationFailed
        case unknown(String)
        
        var massage: String {
            switch self {
            case .sourceNotProvided:
                "Specify file(s) to compress."
            case .accessDenied:
                "Unable to access the specified files/folders."
            case .creationFailed:
                "Unable to create Zip"
            case .unknown(let message):
                "Failed with error \(message)"
            }
        }
    }
 
    private let coordinator = NSFileCoordinator()
    private let fileManager = FileManager.default
    private let temporaryDirectory = FileManager.default.temporaryDirectory
    
    
    func zip(_ sources: [URL]) throws -> ZipDocument {
        if sources.isEmpty {
            throw ZipError.sourceNotProvided
        }
        
        let results = sources.map({$0.startAccessingSecurityScopedResource()})
        if !results.contains(false) {
            print("Not able to call startAccessingSecurityScopedResource for some files. Continue processing anyway...")
        }
        
        let sourceFolder = try createSourceFolder(sources)
        print("source: ", sourceFolder)
        defer {
            do {
                sources.forEach({$0.stopAccessingSecurityScopedResource()})
                try fileManager.removeItem(at: sourceFolder)
            } catch(let error) {
                print("error removing temp files: \(error)")
            }
        }
        
        let zip = try createZipDocument(sourceFolder)
        return zip
    }
    
    
    private func createZipDocument(_ source: URL) throws -> ZipDocument {
        var coordinatorError: NSError?
        var error: Error?
        var zip: ZipDocument?
        
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            readingItemAt: source,
            options: .forUploading,
            error: &coordinatorError
        ) { readerUrl in
            do {
                let data = try Data(contentsOf: readerUrl)
                zip = ZipDocument(data)
            } catch (let e) {
                print("error: ", e)
                error = e
            }
        }
        
        if let error = coordinatorError ?? error {
            throw error
        }
        guard let zip else {
            throw ZipError.creationFailed
        }
        
        return zip

    }
    
    private func createSourceFolder(_ sources: [URL]) throws -> URL {
        if sources.isEmpty {
            throw ZipError.sourceNotProvided
        }
        
        if sources.count == 1 {
            let source = sources.first!
            if (source.isDirectory) {
                let tempFolder = temporaryDirectory.appending(path: source.lastPathComponent)
                if fileManager.fileExists(atPath: tempFolder.path()) {
                    try fileManager.removeItem(at: tempFolder)
                }
                try fileManager.copyItem(at: source, to: tempFolder)
                return tempFolder
            }
        }
        
        
        let tempFolder = temporaryDirectory.appending(path: "archive")
        if fileManager.fileExists(atPath: tempFolder.path()) {
            try fileManager.removeItem(at: tempFolder)
        }
        try fileManager.createDirectory(at: tempFolder, withIntermediateDirectories: true)
                
        for url in sources {
            let fileName = url.lastPathComponent
            try fileManager.copyItem(at: url, to: tempFolder.appending(path: fileName))
        }
        
        return tempFolder
    }
    
}
