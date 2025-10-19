//
//  Routing.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI

struct RootRouter: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        CrowdHomeView()
    }
}
