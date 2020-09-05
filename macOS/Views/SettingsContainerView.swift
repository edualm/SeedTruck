//
//  SettingsContainerView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 05/09/2020.
//

import SwiftUI

struct SettingsContainerView: View {
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    var body: some View {
        SettingsView(actionHandler: SettingsActionHandler(managedObjectContext: managedObjectContext))
    }
}

struct SettingsContainerView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsContainerView()
    }
}
