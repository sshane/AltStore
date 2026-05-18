//
//  UTType+AltStore.swift
//  AltStore
//
//  Created by Riley Testut on 11/3/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import UniformTypeIdentifiers

extension UTType
{
    static let ipa = UTType(importedAs: "com.apple.itunes.ipa")
    static let p12 = UTType(filenameExtension: "p12")!
    static let mobiledevicepairing = UTType(filenameExtension: "mobiledevicepairing")!
}
