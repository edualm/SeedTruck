//
//  TransmissionModelTests.swift
//  Tests iOS
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import XCTest

@testable import SeedTruck

class TransmissionModelTests: XCTestCase {

    func testDecodeFromJSON() {
        let jsonString = """
            {
                "arguments": {
                    "torrents": [
                        {
                            "error": 0,
                            "errorString": "",
                            "eta": -1,
                            "id": 1,
                            "isFinished": false,
                            "leftUntilDone": 0,
                            "name": "Linux Distribution ISO DVD",
                            "peersGettingFromUs": 0,
                            "peersSendingToUs": 0,
                            "rateDownload": 0,
                            "rateUpload": 0,
                            "sizeWhenDone": 1234567890,
                            "status": 6,
                            "uploadRatio": 0.25
                        }
                    ]
                },
                "result": "success",
                "tag": 1
            }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        
        let decoded = try! JSONDecoder().decode(Transmission.RPCResponse.TorrentGet.self, from: jsonData)

        XCTAssertEqual(decoded.result, .success)
    }
}
