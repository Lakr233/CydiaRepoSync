//
//  Extension+String.swift
//  RepoSync
//
//  Created by Lakr Aream on 2021/7/11.
//  Copyright © 2021 Lakr Aream. All rights reserved.
//

import Foundation

extension String {
    mutating func removeSpaces() {
        while hasPrefix(" ") {
            removeFirst()
        }
        while hasSuffix(" ") {
            removeLast()
        }
    }

    mutating func cleanAndReplaceLineBreaker() {
        self = replacingOccurrences(of: "\r\n", with: "\n", options: .literal, range: nil)
        self = replacingOccurrences(of: "\r", with: "\n", options: .literal, range: nil)
    }
}
