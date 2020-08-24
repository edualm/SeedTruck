//
//  DocumentPickerViewController.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

//  https://stackoverflow.com/a/60452526

import UIKit
import MobileCoreServices

class DocumentPickerViewController: UIDocumentPickerViewController {
    private let onDismiss: () -> Void
    private let onPick: (URL) -> ()

    init(supportedTypes: [String], onPick: @escaping (URL) -> Void, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        self.onPick = onPick

        super.init(documentTypes: supportedTypes, in: .open)

        allowsMultipleSelection = false
        delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DocumentPickerViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        onPick(urls.first!)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onDismiss()
    }
}

extension DocumentPickerViewController {
    
    convenience init(torrentPickerWithOnPick onPick: @escaping (URL) -> Void, onDismiss: @escaping () -> Void) {
        //  TODO: Ideally, we want to initialize this with the mime type of "application/x-bittorrent",
        //  but the beta seems to be giving me some issues, eh.
        
        self.init(supportedTypes: [kUTTypeItem as String], onPick: onPick, onDismiss: onDismiss)
    }
}
