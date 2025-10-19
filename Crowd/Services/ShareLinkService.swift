//
//  ShareLinkService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation

final class ShareLinkService {
    func eventDeepLink(id: String) -> URL? {
        // swap to universal link later
        URL(string: "crowd://event/\(id)")
    }
}
