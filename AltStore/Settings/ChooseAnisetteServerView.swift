//
//  ChooseAnisetteServerView.swift
//  AltStore
//
//  Created by Caroline Moore on 5/26/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

import AltStoreCore

struct ChooseAnisetteServerView: View
{
    @State
    private var availableServers: [AnisetteServer]? = UserDefaults.standard.anisetteServers
    
    @State
    private var isLoading = true
    
    @State
    private var preferredURL: URL? = UserDefaults.shared.preferredAnisetteServerURL
    
    @State
    private var customURLText: String = ""
    
    @State
    private var isShowingError = false
    
    @State
    private var errorMessage = ""

    private var localizedTitle: String { String(localized: "Choose Remote Server") }

    var body: some View {
        List {
            if let availableServers
            {
                Section("Popular") {
                    ForEach(availableServers) { server in
                        SwiftUI.Button {
                            selectPopular(server)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(server.url.host ?? "")
                                    
                                    Text(server.name)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if server.url == preferredURL
                                {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(.rect) // Expand tap target to the full row.
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            else if isLoading
            {
                Section("Popular") {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }

            Section("Custom") {
                HStack {
                    TextField("https://", text: $customURLText)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit {
                            Task { await submitCustom() }
                        }

                    if isCustomSelected
                    {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .navigationTitle(localizedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadServers() }
        .refreshable { await loadServers() }
        .alert("Couldn't select server", isPresented: $isShowingError) {
            SwiftUI.Button("OK", role: .cancel) { }
        } message: { Text(errorMessage) }
    }

    private var isCustomSelected: Bool
    {
        guard let preferredURL, let availableServers else { return false }
        return !availableServers.contains { $0.url == preferredURL }
    }
}

private extension ChooseAnisetteServerView
{
    func loadServers() async
    {
        isLoading = true
        defer { isLoading = false }

        do
        {
            availableServers = try await AnisetteServer.fetchAvailable()
        }
        catch
        {
            // Keep showing cached servers (if any).
            Logger.sideload.error("Failed to load anisette servers: \(error.localizedDescription, privacy: .public)")
        }

        // If preferred URL isn't in the list, it's the user's custom server.
        if let preferredURL, availableServers?.contains(where: { $0.url == preferredURL }) != true
        {
            customURLText = preferredURL.absoluteString.replacingOccurrences(of: "\(preferredURL.scheme ?? "")://", with: "") // Remove scheme for display
        }
    }

    func selectPopular(_ server: AnisetteServer)
    {
        guard server.url != preferredURL else { return }

        UserDefaults.shared.preferredAnisetteServerURL = server.url
        Keychain.shared.anisetteADIPB = nil // adi.pb is provisioned against a specific server; clear it so we can re-provision cleanly.
        preferredURL = server.url
        customURLText = ""
    }

    func submitCustom() async
    {
        var input = customURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        if !input.hasPrefix("http://") && !input.hasPrefix("https://")
        {
            input = "https://\(input)"
        }
        
        guard let url = URL(string: input) else
        {
            errorMessage = String(localized: "The provided URL is invalid.")
            isShowingError = true
            return
        }
        
        guard url != preferredURL else { return }

        do
        {
            try await AnisetteServer.validate(url: url)

            UserDefaults.shared.preferredAnisetteServerURL = url
            Keychain.shared.anisetteADIPB = nil // adi.pb is provisioned against a specific server; clear it so we can re-provision cleanly.
            preferredURL = url

            // If URL is in our provided list, clear the field (selection will be reflected in the list).
            if let availableServers, availableServers.contains(where: { $0.url == url })
            {
                customURLText = ""
            }
        }
        catch
        {
            errorMessage = error.localizedDescription
            isShowingError = true
        }
    }
}

extension ChooseAnisetteServerView
{
    static func makeViewController() -> UIHostingController<some View>
    {
        let view = ChooseAnisetteServerView()

        let hostingController = UIHostingController(rootView: view)
        hostingController.navigationItem.largeTitleDisplayMode = .never
        hostingController.navigationItem.title = view.localizedTitle
        return hostingController
    }
}

#Preview {
    NavigationStack {
        ChooseAnisetteServerView()
    }
}
