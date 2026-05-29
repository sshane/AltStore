//
//  FetchPairingFileOperation.swift
//  AltStore
//
//  Created by Caroline Moore on 5/28/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import Foundation

import AltStoreCore
import AltSign
import Roxas

import Minimuxer

@objc(FetchPairingFileOperation)
class FetchPairingFileOperation: ResultOperation<Void>, @unchecked Sendable
{
    let context: OperationContext

    init(context: OperationContext)
    {
        self.context = context
    }

    override func main()
    {
        super.main()

        if let error = self.context.error
        {
            self.finish(.failure(error))
            return
        }

        Task<Void, Never>
        {
            do
            {
                Logger.sideload.notice("Fetching pairing file from AltServer...")

                let pairingFile = try await self.fetchPairingFile()

                // Validate the plist: must contain either UDID (lockdown) or private_key (RP-pairing).
                struct PairingFile: Decodable
                {
                    var UDID: String?
                    var private_key: Data?
                }

                guard let decodedFile = try? PropertyListDecoder().decode(PairingFile.self, from: pairingFile),
                      decodedFile.UDID != nil || decodedFile.private_key != nil
                else
                {
                    Logger.sideload.error("Invalid pairing file from AltServer: missing UDID/private_key.")
                    throw OperationError.invalidPairingFile()
                }

                Keychain.shared.devicePairingFile = pairingFile

                try Minimuxer.startSession()

                Logger.sideload.notice("Configured pairing file from AltServer (\(pairingFile.count) bytes).")

                self.finish(.success(()))
            }
            catch
            {
                self.finish(.failure(error))
            }
        }
    }
}

private extension FetchPairingFileOperation
{
    func fetchPairingFile() async throws -> Data
    {
        guard let server = self.context.server else { throw OperationError.serverNotFound }
        guard server.connectionType == .wired else { throw OperationError.wiredConnectionRequired() }
        guard let udid = UserDefaults.shared.deviceID else { throw OperationError.unknownUDID }

        return try await withCheckedThrowingContinuation { continuation in
            // Existing bug can call completion twice, so guard against the continuation assert.
            func finish(_ result: Result<Data, Error>)
            {
                guard !self.isFinished else { return }
                continuation.resume(with: result)
            }

            ServerManager.shared.connect(to: server) { result in
                switch result
                {
                case .failure(let error):
                    finish(.failure(error))
                case .success(let connection):
                    Logger.sideload.debug("Sending pairing file request...")

                    let request = PairingFileRequest(udid: udid)
                    connection.send(request) { result in
                        switch result
                        {
                        case .failure(let error):
                            Logger.sideload.error("Failed to send pairing file request. \(error.localizedDescription, privacy: .public)")
                            finish(.failure(error))

                        case .success:
                            Logger.sideload.debug("Waiting for pairing file...")
                            connection.receiveResponse { result in
                                switch result
                                {
                                case .failure(let error):
                                    Logger.sideload.error("Failed to receive pairing file response. \(error.localizedDescription, privacy: .public)")
                                    finish(.failure(error))

                                case .success(.error(let response)):
                                    Logger.sideload.error("AltServer failed to generate pairing file. \(response.error.localizedDescription, privacy: .public)")
                                    finish(.failure(response.error))

                                case .success(.pairingFile(let response)):
                                    // Log byte count only; bytes contain sensitive info (device identfier) we don't want to expose.
                                    Logger.sideload.notice("Received pairing file (\(response.pairingFile.count) bytes).")
                                    finish(.success(response.pairingFile))

                                case .success: finish(.failure(ALTServerError(.unknownResponse)))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
