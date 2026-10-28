//
//  IntervalSettings.swift
//  Ghisa
//
//  Created by Simone Folino on 28/10/26.
//

import Foundation

struct IntervalSettings {
    var prepare = 10
    var work = 120
    var rest = 60
    var rounds = 3
    
    static func format(_ seconds: Int) -> String {
        "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }
}
