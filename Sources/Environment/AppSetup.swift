//
//  AppSetup.swift
//  Ello
//
//  Created by Sean Dougherty on 11/21/14.
//  Copyright (c) 2014 Ello. All rights reserved.
//

import UIKit
import SwiftyUserDefaults

public class AppSetup {
    public struct Size {
        public static let calculatorHeight = CGFloat(20)
    }

    lazy var useStaging = true
    var isTesting = false

    class var sharedState : AppSetup {
        struct Static {
            static let instance = AppSetup()
        }
        return Static.instance
    }

    public init() {
        useStaging = Defaults["ElloUseStaging"].bool ?? true
        if let inTests: AnyClass = NSClassFromString("XCTest") { isTesting = true }
    }
}
