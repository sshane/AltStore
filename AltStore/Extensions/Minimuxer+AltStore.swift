//
//  Minimuxer+AltStore.swift
//  AltStore
//
//  Created by Caroline Moore on 5/6/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import Foundation

import AltStoreCore

import Minimuxer

extension Minimuxer
{
    // Starts minimuxer (idempotent) and verifies the user's device is reachable via the pairing file.
    static func startSession() throws
    {
        guard
            let pairingData = AppManager.shared.devicePairingFile,
            let pairingFile = String(data: pairingData, encoding: .utf8)
        else { throw OperationError.missingPairingFile() }

        let logPath = URL.documentsDirectory.appending(path: "minimuxer.txt").path

        do
        {
            Minimuxer.retargetUsbmuxdAddr()
            try Minimuxer.start(pairingFile: pairingFile, logPath: logPath)
        }
        catch
        {
            Logger.sideload.error("Failed to start device client: \(error.localizedDescription, privacy: .public)")
            throw (error as NSError).withLocalizedFailure(String(localized: "AltStore couldn’t start the device client."))
        }

        guard Minimuxer.isDeviceReachable() else { throw OperationError.vpnNotConnected() }
    }

    // Returns false when the VPN tunnel is down, the network is unavailable, or the device isn't responding.
    static func isDeviceReachable() -> Bool
    {
        guard Minimuxer.testDeviceConnection(ifaddr: "10.7.0.1") else
        {
            Logger.sideload.error("Device not reachable at 10.7.0.1 — VPN tunnel likely down.")
            return false
        }
        return true
    }
}
