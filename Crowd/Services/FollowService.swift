//
//  FollowService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation

final class FollowService {
    static let shared = FollowService()
    
    private let followedHostsKey = "followedHostIds"
    
    private init() {}
    
    func isFollowing(hostId: String) -> Bool {
        getFollowedHosts().contains(hostId)
    }
    
    func follow(hostId: String) {
        var hosts = getFollowedHosts()
        guard !hosts.contains(hostId) else { return }
        hosts.append(hostId)
        saveFollowedHosts(hosts)
        print("✅ FollowService: Now following host \(hostId)")
    }
    
    func unfollow(hostId: String) {
        var hosts = getFollowedHosts()
        hosts.removeAll { $0 == hostId }
        saveFollowedHosts(hosts)
        print("✅ FollowService: Unfollowed host \(hostId)")
    }
    
    private func getFollowedHosts() -> [String] {
        UserDefaults.standard.stringArray(forKey: followedHostsKey) ?? []
    }
    
    private func saveFollowedHosts(_ hosts: [String]) {
        UserDefaults.standard.set(hosts, forKey: followedHostsKey)
    }
}

