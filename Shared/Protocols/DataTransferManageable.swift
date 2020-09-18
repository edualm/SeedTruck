//
//  DataTransferManageable.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 18/09/2020.
//

import Foundation

protocol DataTransferManageable {
    
    func sendUpdateToWatch(completionHandler: ((Result<Int, Error>) -> ())?)
}
