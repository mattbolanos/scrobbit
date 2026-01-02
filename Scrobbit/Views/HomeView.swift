//
//  HomeView.swift
//  Scrobbit
//
//  Created by Matt Bolaños on 12/24/25.
//

import SwiftUI

struct HomeView: View {

    var body: some View {
        NavigationStack {
            VStack {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .foregroundColor(.red)
                        Text("Connect your Last.fm account to start scrobbling")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
}
