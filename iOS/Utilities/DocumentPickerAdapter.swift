//
//  DocumentPickerViewController.swift
//  SeedTruck (iOS)
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

class DocumentPickerAdapter: NSObject, UIDocumentPickerDelegate {
    
    private let onDismiss: () -> Void
    private let onPick: (URL) -> ()
    
    public let picker: UIDocumentPickerViewController
    
    init(torrentPickerWithOnPick onPick: @escaping (URL) -> Void, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        self.onPick = onPick
        
        self.picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType(exportedAs: "io.edr.seedtruck.torrent")],
                                                     asCopy: true)
        
        super.init()
        
        picker.delegate = self
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        onPick(urls.first!)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onDismiss()
    }
}
