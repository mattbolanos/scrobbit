//
//  HomeView.swift
//  Scrobbit
//
//  Created by Matt Bolaños on 12/24/25.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
                HStack (spacing: 12) {
                    ZStack {
                          Circle()
                            .fill(.red.opacity(0.15))
                              .frame(width: 44, height: 44)
                          
                        Image("last-fm")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                              
                      }
                    

                    Text("Connect Last.fm account")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
      
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
                .cornerRadius(16)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                       RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.red.opacity(0.5), lineWidth: 2)
                   )
                .padding()
            
                Spacer()

            
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
}
