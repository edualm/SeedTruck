//
//  MenuItem.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import Foundation

struct MenuItem: Hashable {
    
    let name: String
    let systemImage: String
    let action: () -> ()
    
    static func == (lhs: MenuItem, rhs: MenuItem) -> Bool {
        lhs.name == rhs.name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
