//
//  TransmissionModelTests.swift
//  Tests iOS
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import XCTest

@testable import SeedTruck

class TransmissionModelTests: XCTestCase {

    func testPositivePollingInterval() {
        XCTAssertEqual(PollingInterval.timeInterval(for: 2), 2)
        XCTAssertEqual(PollingInterval.timeInterval(for: 300), 300)
    }

    func testManualPollingInterval() {
        XCTAssertNil(PollingInterval.timeInterval(for: 0))
        XCTAssertNil(PollingInterval.timeInterval(for: -1))
    }

    func testDecodesJSONRPCResponseAndSnakeCaseTorrentFields() throws {
        let jsonString = """
            {
                "jsonrpc": "2.0",
                "result": {
                    "torrents": [
                        {
                            "error": 0,
                            "error_string": "",
                            "eta": -1,
                            "id": 1,
                            "is_finished": false,
                            "left_until_done": 0,
                            "name": "Linux Distribution ISO DVD",
                            "peers_getting_from_us": 0,
                            "peers_sending_to_us": 0,
                            "percent_done": 1,
                            "rate_download": 0,
                            "rate_upload": 0,
                            "size_when_done": 1234567890,
                            "status": 6,
                            "upload_ratio": 0.25
                        }
                    ]
                },
                "id": "request-1"
            }
        """
        let jsonData = try XCTUnwrap(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(
            Transmission.RPCResponse<Transmission.TorrentGetResult>.self,
            from: jsonData
        )

        XCTAssertEqual(decoded.jsonrpc, "2.0")
        XCTAssertEqual(decoded.id, "request-1")
        XCTAssertEqual(decoded.result?.torrents.first?.name, "Linux Distribution ISO DVD")
        XCTAssertEqual(decoded.result?.torrents.first?.sizeWhenDone, 1_234_567_890)
        XCTAssertNil(decoded.error)
    }
}
