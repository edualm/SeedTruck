//
//  GeneralSettingsView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import SwiftUI

struct GeneralSettingsView: View {
    
    enum AutoUpdateInterval: Int, CaseIterable, Hashable {
        
        case twoSeconds
        case fiveSeconds
        case tenSeconds
        case thirtySeconds
        case oneMinute
        case twoMinutes
        case fiveMinutes
        case never
        
        var userFacingString: String {
            switch self {
            case .twoSeconds:
                return "2 seconds"
            case .fiveSeconds:
                return "5 seconds"
            case .tenSeconds:
                return "10 seconds"
            case .thirtySeconds:
                return "30 seconds"
            case .oneMinute:
                return "1 minute"
            case .twoMinutes:
                return "2 minutes"
            case .fiveMinutes:
                return "5 minutes"
            case .never:
                return "Never (manually)"
            }
        }
    }
    
    /* @AppStorage("autoUpdateInterval") */ var autoUpdateInterval: Int = 5
    
    @State private var autoUpdateIntervalSliderValue: Double = 1
    
    var body: some View {
        Form {
            HStack {
                Spacer()
                Text("⚠️ These settings do not work yet!")
                    .foregroundColor(.black)
                    .padding()
                Spacer()
            }
            .background(Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 25.0))
            
            Divider()
                .padding([.top, .bottom])
            
            Section(header: Text("Refresh/update data every...").font(.headline)) {
                Slider(value: $autoUpdateIntervalSliderValue, in: 0...Double(AutoUpdateInterval.allCases.count - 1), step: 1)
                HStack {
                    Spacer()
                    Text(AutoUpdateInterval(rawValue: Int(autoUpdateIntervalSliderValue))!.userFacingString)
                    Spacer()
                }
            }
            
            Divider()
                .padding([.top, .bottom])
            
            Section(header: Text("Do not prompt me when adding...")
                        .font(.headline),
                    footer: Text("These settings only apply when you only have one server.\nYou will always be prompted when you have multiple servers configured.")
                        .font(.caption)) {
                Toggle("Magnet Links", isOn: .constant(false))
                Toggle("Torrents", isOn: .constant(false))
            }
        }
    }
}

struct GeneralSettingsView_Previews: PreviewProvider {
    
    static var previews: some View {
        GeneralSettingsView()
    }
}
