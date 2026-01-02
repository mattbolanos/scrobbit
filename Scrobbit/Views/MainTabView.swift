import SwiftUI

struct MainTabView: View {
    var body: some View {
        if #available(iOS 18.0, *) {
            TabView {
                Tab("Home", systemImage: "music.note.house") {
                    HomeView()
                }
                
                
                Tab("History", systemImage: "list.triangle") {
                    HistoryView()
                }
                .badge("!")
                
                
                Tab("Settings", systemImage: "gearshape") {
                    SettingsView()
                }
            }
            .tint(.red)
            
        } else {
           TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "music.note.house")
                }
                
                HistoryView()
                .tabItem {
                    Label("History", systemImage: "list.triangle")
                }.badge("!")
                
                SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
           }
           .tint(.red)
        }
    }
}

#Preview {
    MainTabView()
}
