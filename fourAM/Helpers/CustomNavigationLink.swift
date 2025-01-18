//
//  CustomNavigationLink.swift
//  fourAM
//
//  Created by Jonas on 2025-01-18.
//

import SwiftUI

struct CustomNavigationLink: View {
    let title: String
    let icon: String
    let viewName: String
    @Binding var selectedView: String?

    var body: some View {
        NavigationLink(
            destination: Text("\(title) View"), // Replace with actual destination
            tag: viewName,
            selection: $selectedView
        ) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(selectedView == viewName ? .gray : .indigo) // Change icon color
                Text(title)
            }
            .padding(8)
            .background(selectedView == viewName ? Color.gray.opacity(0.2) : Color.clear) // Change background
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle()) // Removes default blue selection styling
    }
}
