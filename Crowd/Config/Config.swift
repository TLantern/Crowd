//
//  Config.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation

struct Config {
    let environment: String
    let apiBaseURL: URL?
    let superwallAPIKey: String

    static func build() -> Config {
        #if DEBUG
        return Config(
            environment: "dev",
            apiBaseURL: nil,
            superwallAPIKey: "pk_kCuiXnZu81VQ1MgcLwS9r"
        )
        #else
        return Config(
            environment: "prod",
            apiBaseURL: URL(string: "https://api.yourdomain.com"),
            superwallAPIKey: "pk_kCuiXnZu81VQ1MgcLwS9r"
        )
        #endif
    }
}
