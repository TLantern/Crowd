//
//  CrowdError.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation

enum CrowdError: Error {
    case network
    case decoding
    case invalidInput(String)
    case notFound
    case invalidResponse
    case custom(String)
}
