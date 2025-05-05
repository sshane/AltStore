//
//  ImportCertificateViewController.swift
//  AltStore
//
//  Created by Riley Testut on 5/5/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import UIKit

import AltStoreCore
import AltSign
import Roxas

extension ImportCertificateViewController
{
    typealias ImportError = ImportErrorCode.Error
    enum ImportErrorCode: Int, ALTErrorEnum, CaseIterable
    {
        case incorrectPassword
        case invalidCertificate
        
        var errorFailureReason: String {
            switch self
            {
            case .incorrectPassword: return NSLocalizedString("The provided password is incorrect, or the certificate itself is invalid.", comment: "")
            case .invalidCertificate: return NSLocalizedString("The provided certificate is expired or was created by another Apple ID.", comment: "")
            }
        }
    }
}

class ImportCertificateViewController: UIViewController
{
    var validCertificates: [ALTCertificate]?
    var completionHandler: ((Result<ALTCertificate, Error>) -> Void)?
    
    private var _importCertificateContinuation: CheckedContinuation<URL, Error>?
    
    @IBOutlet private var placeholderView: RSTPlaceholderView!
    @IBOutlet private var importButton: PillButton!
    @IBOutlet private var cancelButton: UIButton!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.navigationItem.hidesBackButton = true
        
        self.placeholderView.textLabel.isHidden = true
        
        self.placeholderView.detailTextLabel.textAlignment = .left
        self.placeholderView.detailTextLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        self.placeholderView.detailTextLabel.text = NSLocalizedString("AltStore is unable to use an existing signing certificate, so it must create a new one. This will cause any apps installed with AltStore on other devices to stop working.\n\nTo prevent this, please export the signing certificate from AltStore's settings on another device and import it below.", comment: "")
        
        self.importButton.preferredFont = UIFont.systemFont(ofSize: 19, weight: .semibold)
        self.cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
    }
}

private extension ImportCertificateViewController
{
    @IBAction func importSigningCertificate(_ sender: UIButton)
    {
        sender.isIndicatingActivity = true
        self.cancelButton.isEnabled = false
        
        Task<Void, Never> {
            do
            {
                let fileURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                    let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.p12], asCopy: true)
                    documentPicker.delegate = self
                    self.present(documentPicker, animated: true, completion: nil)
                    
                    self._importCertificateContinuation = continuation
                }
                
                let data = try Data(contentsOf: fileURL)
                
                let password = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                    let alertController = UIAlertController(title: NSLocalizedString("Enter Password", comment: ""), message: NSLocalizedString("Please enter the password used to protect this certificate.", comment: ""), preferredStyle: .alert)
                    alertController.addTextField { textField in
                        textField.placeholder = "Password"
                        textField.autocorrectionType = .no
                        textField.autocapitalizationType = .none
                        textField.keyboardType = .default
                    }
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                        continuation.resume(throwing: CancellationError())
                    })
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Import", comment: ""), style: .default) { [weak alertController] _ in
                        let textField = alertController?.textFields?.first
                        
                        let password = textField?.text ?? ""
                        continuation.resume(returning: password)
                    })
                    
                    self.present(alertController, animated: true)
                }
                
                guard let signingCertificate = ALTCertificate(p12Data: data, password: password) else { throw ImportError(.incorrectPassword) }
                guard let certificate = self.validCertificates?.first(where: { $0.serialNumber == signingCertificate.serialNumber }) else { throw ImportError(.invalidCertificate) }
                
                signingCertificate.machineIdentifier = certificate.machineIdentifier
                self.completionHandler?(.success(signingCertificate))
            }
            catch is CancellationError
            {
                // Ignore
                sender.isIndicatingActivity = false
                self.cancelButton.isEnabled = true
            }
            catch
            {
                await self.presentAlert(title: NSLocalizedString("Unable to Import Certificate", comment: ""), message: error.localizedDescription)
                
                sender.isIndicatingActivity = false
                self.cancelButton.isEnabled = true
            }
        }
    }
    
    @IBAction func cancel(_ sender: UIButton)
    {
        Task<Void, Never> {
            do
            {
                let action = UIAlertAction(title: NSLocalizedString("Skip", comment: ""), style: .destructive)
                try await self.presentConfirmationAlert(title: NSLocalizedString("Skip Importing Certificate?", comment: ""), message: NSLocalizedString("Apps installed with AltStore on other devices may stop working.", comment: ""), primaryAction: action)
                
                self.completionHandler?(.failure(CancellationError()))
            }
            catch
            {
                // Ignore cancellation
            }
        }
    }
}

extension ImportCertificateViewController: UIDocumentPickerDelegate
{
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
        guard let fileURL = urls.first else { return }
        
        self._importCertificateContinuation?.resume(returning: fileURL)
        self._importCertificateContinuation = nil
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController)
    {
        self._importCertificateContinuation?.resume(throwing: CancellationError())
        self._importCertificateContinuation = nil
    }
}
