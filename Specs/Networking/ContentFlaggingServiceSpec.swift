//
//  ContentFlaggingServiceSpec.swift
//  Ello
//
//  Created by Sean on 2/25/15.
//  Copyright (c) 2015 Ello. All rights reserved.
//

import Quick
import Moya
import Nimble

class ContentFlaggingServiceSpec: QuickSpec {

    override func spec() {
        describe("-flagContent:") {

            var subject = ContentFlaggingService()

            context("success") {
                beforeEach {
                    ElloProvider.sharedProvider = MoyaProvider(endpointsClosure: ElloProvider.endpointsClosure, stubResponses: true)
                }

            }
            
        }
    }
}