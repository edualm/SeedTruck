//
//  FileSize.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

protocol FileSizeRepresenting {
    
    var bytes: Int { get }
}

extension FileSizeRepresenting {
    
    var fileSizeForPresentationBase: String {
        ""
    }
}

struct FileSize: FileSizeRepresenting {
    
    let bytes: Int
    
    init(bytes: Int) {
        self.bytes = bytes
    }
    
    var fileSizeForPresentation: String {
        fileSizeForPresentationBase
    }
}

struct FileTransmissionSpeed: FileSizeRepresenting {
    
    let bytes: Int
    
    init(bytesPerSecond: Int) {
        self.bytes = bytesPerSecond
    }
    
    var fileSizeForPresentation: String {
        fileSizeForPresentationBase + "/s"
    }
}
