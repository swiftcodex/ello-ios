//
//  Regionable.swift
//  Ello
//
//  Created by Sean on 2/11/15.
//  Copyright (c) 2015 Ello. All rights reserved.
//

import Foundation

@objc
public protocol Regionable {
    var kind: String { get }
    var isRepost: Bool { get set }
    func toJSON() -> [String: AnyObject]
    func coding() -> NSCoding
}
