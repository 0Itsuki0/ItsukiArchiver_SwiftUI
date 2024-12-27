//
//  ContentView.swift
//  ItsukiZipper
//
//  Created by Itsuki on 2024/12/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var fileUrls: [URL] = []
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var zipDocument: ZipDocument?
    @State private var error: Error?
    @State private var exportedUrl: URL?
    
    @State private var isDropTargeted: Bool = false

    private let manager = ZipManager()

    var body: some View {
        HStack {
            VStack(spacing: 0) {
                Text("Added Files")
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.2))
                
                if fileUrls.isEmpty {
                    
                    Text("Drag & Drop Files or Click on Add Files")
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    
                } else {
                    List {
                        ForEach(fileUrls, id: \.self) { url in
                            Text("\(url.lastPathComponent)")
                                .padding(.vertical, 4)
                        }
                    }
                }
               
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .background(.black.opacity(0.8))


            VStack(spacing: 16) {
                Button(action: {
                    showImporter = true
                }, label: {
                    Text("Add Files")
                        .frame(maxWidth: .infinity)
                })
                
                Button(action: {
                    do {
                        self.zipDocument = try manager.zip(fileUrls)
                        showExporter = true
                    } catch(let error) {
                        self.error = error
                        print("error: \(error)")
                    }
                    
                }, label: {
                    Text("Compress")
                        .frame(maxWidth: .infinity)

                })
            }
            .fixedSize(horizontal: true, vertical: true)
            .frame(width: 120)

            
        }
        .overlay(content: {
            if let error {
                Text("Error: \(error)")
                    .multilineTextAlignment(.center)
                    .padding(.all, 16)
                    .frame(width: 160, height: 120)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black))
                    .overlay(alignment: .topTrailing, content: {
                        Button(action: {
                            self.error = nil
                        }, label: {
                            Image(systemName: "xmark.circle.fill")
                                .padding(.all, 8)
                        })
                        .buttonStyle(.plain)
                    })
            }
        })
        .overlay(content: {
            if let exportedUrl {
                Text("**Zip saved**\n \(exportedUrl.path())")
                    .multilineTextAlignment(.center)
                    .padding(.all, 16)
                    .frame(width: 160, height: 120)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black))
                    .overlay(alignment: .topTrailing, content: {
                        Button(action: {
                            self.exportedUrl = nil
                        }, label: {
                            Image(systemName: "xmark.circle.fill")
                                .padding(.all, 8)
                        })
                        .buttonStyle(.plain)
                    })
            }
        })
        .frame(width: 400, height: 280)
        .fixedSize()
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.item, .directory],
            allowsMultipleSelection: true
        ) { result in
            print("result: \(result)")
            
            switch result {
            case .success(let urls):
                self.fileUrls = urls
                
            case .failure(let error):
                self.error = error
                print("failed with error: \(error)")
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: zipDocument,
            contentType: .zipDocumentType,
            defaultFilename: "archive.zip"
        ) { result in
            
            switch result {
                
            case .success(let url):
                print("Saved to \(url)")
                self.exportedUrl = url
                
            case .failure(let error):
                self.error = error
                print("failed with error: \(error)")
            }
        }
        // for drag and drop
        .overlay(content: {
            if isDropTargeted {
                Image(systemName: "plus")
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.bold)
                    .foregroundStyle(.black.opacity(0.8))
                    .padding(.all, 120)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.gray.opacity(0.4))
            }
        })
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: { providers in
            print(providers.count)
            
            do {
                try processProviders(providers)
            } catch (let error) {
                print("error: \(error)")
                self.error = error
            }
            
            return true
        })

        
    }
    
    nonisolated private func processProviders(_ providers: [NSItemProvider]) throws {
        Task {
            var newUrls: [URL] = []
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    let data = try await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
                    if let data = data as? Data, let fileURL = URL(dataRepresentation: data, relativeTo: nil) {
                        newUrls.append(fileURL)
                    }
                }
            }
            DispatchQueue.main.async(execute: { [newUrls] in
                self.fileUrls = newUrls
            })
        }
    }
}

#Preview {
    ContentView()
}
