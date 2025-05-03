//
//  ActionButton.swift
//  UltimateSwiftKitTester
//
//  Created by knc on 04.05.25.
//

import SwiftUI

struct ActionButton: View {
    let title: String
    let iconName: String
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.system(size: 20))
            
            Text(title)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue)
        )
        .foregroundColor(.white)
    }
}
