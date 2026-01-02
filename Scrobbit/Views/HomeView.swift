import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(LastFmService.self) var lastFmService

    var body: some View {
        NavigationStack {
            VStack {
                if !lastFmService.isAuthenticated {
                    Button {
                        Task {
                            try? await lastFmService.authenticate()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(.red.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                
                                Image("last-fm")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                            }
                            VStack (alignment: .leading){
                                Text("Last.fm")
                                    .font(.headline)
                                    
                                Text(lastFmService.statusDescription)
                                    .font(.subheadline)
                                    
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            colorScheme == .dark ?
                            Color.red.opacity(0.2) :
                            Color.red.opacity(0.05)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.red.opacity(0.5), lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle(lastFmService.username != "" ? lastFmService.username : "Scrobbit")

            
        }
    }
}

#Preview {
    HomeView()
        .environment(LastFmService())
}
