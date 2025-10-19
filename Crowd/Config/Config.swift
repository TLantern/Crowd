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

    static func build() -> Config {
        #if DEBUG
        return Config(environment: "dev", apiBaseURL: nil)
        #else
        return Config(environment: "prod", apiBaseURL: URL(string: "https://api.yourdomain.com"))
        #endif
    }
}
