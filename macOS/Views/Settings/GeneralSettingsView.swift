//
//  GeneralSettingsView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import SwiftUI

struct GeneralSettingsView: View {
    
    @AppStorage(Constants.StorageKeys.autoUpdateInterval) var autoUpdateIntervalInSeconds: Int = 2
    
    @State private var autoUpdateIntervalSliderValue: Double = 0
    
    func onAppear() {
        autoUpdateIntervalSliderValue = Double(AutoUpdateInterval(seconds: autoUpdateIntervalInSeconds).rawValue)
    }
    
    func onSliderChange() {
        guard let newInterval = AutoUpdateInterval(rawValue: Int(autoUpdateIntervalSliderValue)) else {
            autoUpdateIntervalSliderValue = 0
            autoUpdateIntervalInSeconds = 2
            
            return
        }
        
        autoUpdateIntervalInSeconds = newInterval.secondsValue
    }
    
    var body: some View {
        Form {
            Section(header: Text("Refresh/update data every...").font(.headline)) {
                Slider(value: $autoUpdateIntervalSliderValue,
                       in: 0...Double(AutoUpdateInterval.allCases.count - 1),
                       step: 1,
                       onEditingChanged: { _ in onSliderChange() })
                Text(AutoUpdateInterval(rawValue: Int(autoUpdateIntervalSliderValue))!.userFacingString)
                    .centered()
                VStack {
                    Text("Changes will be reflected the next time an update is triggered.")
                    Text("This setting also affects the rate at which a torrent detail is updated.")
                }
                    .font(.caption)
                    .padding(.top)
                    .centered()
            }
        }
        .onAppear(perform: onAppear)
        .frame(height: 100)
    }
}

struct GeneralSettingsView_Previews: PreviewProvider {
    
    static var previews: some View {
        GeneralSettingsView()
    }
}
