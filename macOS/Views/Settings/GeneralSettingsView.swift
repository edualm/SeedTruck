//
//  GeneralSettingsView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import SwiftUI

struct GeneralSettingsView: View {
    
    var body: some View {
        Form {
            Section(header: Text("Refresh/update data every...").font(.headline)) {
                Slider(value: .constant(3), in: 0...9)
                HStack {
                    Spacer()
                    Text("15 seconds")
                    Spacer()
                }
            }
            
            Divider()
                .padding([.top, .bottom])
            
            Section(header: Text("Do not prompt me when adding...").font(.headline), footer: Text("These settings only apply when you only have one server.").font(.caption)) {
                Toggle("Magnet Links", isOn: .constant(false))
                Toggle("Torrents", isOn: .constant(false))
            }
        }.frame(width: 500)
    }
}

struct GeneralSettingsView_Previews: PreviewProvider {
    
    static var previews: some View {
        GeneralSettingsView()
    }
}
