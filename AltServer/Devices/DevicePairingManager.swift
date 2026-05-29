//
//  DevicePairingManager.swift
//  AltServer
//
//  Created by Caroline Moore on 5/28/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import Foundation
import IDevice

// Swift wrapper around idevice to generate an RP-pairing file via wired connection.
class DevicePairingManager
{
    static let shared = DevicePairingManager()

    private init() {}
    
    func generatePairingFile(forDeviceWithUDID udid: String, hostName: String) async throws -> Data
    {
        // 1. Connect to usbmuxd and resolve the device_id (required by idevice) for this UDID.
        var muxConnection: OpaquePointer? // Use OpaquePointer because we can't import expected type 'UsbmuxdConnectionHandle'
        if let connectionError = idevice_usbmuxd_new_default_connection(0, &muxConnection)
        {
            throw RemotePairingError.pairingFailed(ffiError: connectionError)
        }
        defer { idevice_usbmuxd_connection_free(muxConnection) }

        let deviceID = try self.resolveDeviceID(forUDID: udid, via: muxConnection)

        // 2. Build a device provider.
        var address: OpaquePointer?
        if let addressError = idevice_usbmuxd_default_addr_new(&address)
        {
            throw RemotePairingError.pairingFailed(ffiError: addressError)
        }

        var provider: OpaquePointer?
        if let providerError = usbmuxd_provider_new(address, 0, udid, deviceID, hostName, &provider)
        {
            throw RemotePairingError.pairingFailed(ffiError: providerError)
        }
        defer { idevice_provider_free(provider) }

        // 3. Pair. pin_callback is NULL (idevice substitutes "000000"). Triggers the on-device "Trust" prompt.
        var pairingFileHandle: OpaquePointer?
        if let pairingError = tunnel_pair_usb(provider, hostName, nil, nil, &pairingFileHandle)
        {
            throw RemotePairingError.couldntPairWithDevice(ffiError: pairingError)
        }
        defer { rp_pairing_file_free(pairingFileHandle) }

        // 4. Serialize the plist into Swift Data.
        var bytes: UnsafeMutablePointer<UInt8>?
        var length: UInt = 0
        if let serializationError = rp_pairing_file_to_bytes(pairingFileHandle, &bytes, &length)
        {
            throw RemotePairingError.pairingFailed(ffiError: serializationError)
        }

        guard let bytes else
        {
            throw RemotePairingError.pairingFailed()
        }
        defer { idevice_data_free(bytes, length) }

        return Data(bytes: bytes, count: Int(length))
    }
}

private extension DevicePairingManager
{
    // Finds the device_id matching this UDID in usbmuxd's device list.
    func resolveDeviceID(forUDID udid: String, via muxConnection: OpaquePointer?) throws -> UInt32
    {
        var devices: UnsafeMutablePointer<OpaquePointer?>?
        var deviceCount: Int32 = 0
        if let devicesError = idevice_usbmuxd_get_devices(muxConnection, &devices, &deviceCount)
        {
            throw RemotePairingError.pairingFailed(ffiError: devicesError)
        }
        defer { idevice_usbmuxd_device_list_free(devices, deviceCount) }

        for i in 0 ..< Int(deviceCount)
        {
            guard let device = devices?[i],
                  let udidCString = idevice_usbmuxd_device_get_udid(device)
            else { continue }
            defer { idevice_string_free(udidCString) }

            if String(cString: udidCString) == udid
            {
                return idevice_usbmuxd_device_get_device_id(device)
            }
        }

        throw RemotePairingError.deviceNotConnected(udid: udid)
    }
}

extension RemotePairingError
{
    enum Code: Int, ALTErrorCode
    {
        typealias Error = RemotePairingError

        case deviceNotConnected
        case couldntPairWithDevice
        case pairingFailed
    }

    static func deviceNotConnected(udid: String, file: String = #fileID, line: UInt = #line) -> RemotePairingError {
        RemotePairingError(code: .deviceNotConnected, udid: udid, sourceFile: file, sourceLine: line)
    }

    static func couldntPairWithDevice(ffiError: UnsafeMutablePointer<IdeviceFfiError>?, file: String = #fileID, line: UInt = #line) -> RemotePairingError {
        RemotePairingError(code: .couldntPairWithDevice, ffiError: ffiError, sourceFile: file, sourceLine: line)
    }

    static func pairingFailed(ffiError: UnsafeMutablePointer<IdeviceFfiError>? = nil, file: String = #fileID, line: UInt = #line) -> RemotePairingError {
        RemotePairingError(code: .pairingFailed, ffiError: ffiError, sourceFile: file, sourceLine: line)
    }
}

struct RemotePairingError: ALTLocalizedError
{
    var code: Code
    var errorTitle: String?
    var errorFailure: String?

    @UserInfoValue var udid: String?
    @UserInfoValue var ffiReason: String?
    @UserInfoValue var ffiCode: Int?

    var sourceFile: String?
    var sourceLine: UInt?

    fileprivate init(code: Code, ffiError: UnsafeMutablePointer<IdeviceFfiError>? = nil, udid: String? = nil, sourceFile: String? = nil, sourceLine: UInt? = nil)
    {
        self.code = code
        self.udid = udid
        self.sourceFile = sourceFile
        self.sourceLine = sourceLine

        if let ffiError
        {
            self.ffiCode = Int(ffiError.pointee.code)
            
            if let message = ffiError.pointee.message
            {
                self.ffiReason = String(cString: message)
            }
            
            idevice_error_free(ffiError)
        }
    }

    var errorFailureReason: String {
        switch self.code
        {
        case .deviceNotConnected:
            return NSLocalizedString("This device isn’t connected to AltServer via USB.", comment: "")
        case .couldntPairWithDevice:
            return NSLocalizedString("AltServer couldn’t pair with this device.", comment: "")
        case .pairingFailed:
            return NSLocalizedString("AltServer couldn’t set up the pairing connection.", comment: "")
        }
    }

    var recoverySuggestion: String? {
        switch self.code
        {
        case .deviceNotConnected:
            return NSLocalizedString("Connect your device to this computer with a cable, then try again.", comment: "")
        case .couldntPairWithDevice:
            return NSLocalizedString("Make sure your device is unlocked, then tap Trust when prompted.", comment: "")
        case .pairingFailed:
            return NSLocalizedString("Try unplugging and reconnecting your device, then try again.", comment: "")
        }
    }
}