//
//  Style.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 30/08/2020.
//

import SwiftUI

enum Style {
    
    #if os(iOS)
    static let list = InsetGroupedListStyle()
    #elseif os(macOS)
    static let list = SidebarListStyle()
    #else
    static let list = DefaultListStyle()
    #endif
    
    #if os(macOS)
    static let navigationView = DefaultNavigationViewStyle()
    #else
    static let navigationView = StackNavigationViewStyle()
    #endif
}
