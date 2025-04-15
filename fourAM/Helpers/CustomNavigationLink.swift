import SwiftUI

struct CustomNavigationLink: View {
    let title: String
    let icon: String
    let viewName: String
    @Binding var selectedView: String?

    var body: some View {
        NavigationLink(value: viewName) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(selectedView == viewName ? .gray : .indigo)
                Text(title)
            }
            .padding(8)
            .background(selectedView == viewName ? Color.gray.opacity(0.2) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
