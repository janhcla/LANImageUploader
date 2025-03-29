//
//  NetworkDiscovery.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 13/03/2025.
//
//  (Ensuring import is present, using types directly)
//

import Foundation
import Network   // Required for NetService, NetServiceBrowser, NWPathMonitor
import OSLog     // Use unified logging system
import AMSMB2    // Required for SMB functionality

// Logger for this specific file/module
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NetworkDiscovery")

// NetworkInfo struct is defined in AppData.swift

// Add NetworkDiscovery class definition before the extension
final class NetworkDiscovery {
    static let shared = NetworkDiscovery()
    private init() {}
}

// MARK: - Main Retrieval Function

internal func retrieveNetworkInfo(targetFolder: String, username: String, password: String, directIP: String? = nil, port: Int? = nil) async throws -> NetworkInfo {
    logger.info("--- Starting retrieveNetworkInfo ---")
    logger.debug("Target Folder: '\(targetFolder)', Username: '\(username)', DirectIP: \(directIP ?? "None"), Port: \(port?.description ?? "Default")")

    // Check network connectivity directly rather than waiting
    guard await NetworkMonitor.shared.isConnected else {
        logger.error("Network connection unavailable.")
        throw NSError(domain: "NetworkDiscovery", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "No network connection available. Please check your Wi-Fi connection."])
    }

    // --- Direct IP Attempt (If Provided) ---
    if let directIP = directIP, !directIP.isEmpty {
        logger.info("Attempting direct connection to IP: \(directIP) with Port: \(port?.description ?? "Default")")
        do {
            let networkInfo = try await attemptConnection(
                ipAddress: directIP,
                targetFolder: targetFolder,
                username: username,
                password: password,
                port: port
            )
            logger.info("--- Successfully found NetworkInfo via Direct IP: \(String(describing: networkInfo)) ---")
            return networkInfo
        } catch {
            logger.warning("Direct IP (\(directIP)) connection failed: \(error.localizedDescription). Falling back to discovery.")
        }
    }

    // --- Network Discovery using Bonjour ---
    logger.info("Starting Bonjour discovery for SMB servers...")
    
    do {
        // Discover SMB servers using Bonjour
        let services = try await NetworkDiscovery.shared.discoverSMBServers(timeout: 5.0)
        logger.info("Found \(services.count) SMB services")
        
        // Try each discovered server
        for service in services {
            do {
                let serverIP = try await NetworkDiscovery.shared.resolveService(service)
                logger.info("Attempting connection to discovered server: \(serverIP)")
                
                let networkInfo = try await attemptConnection(
                    ipAddress: serverIP,
                    targetFolder: targetFolder,
                    username: username,
                    password: password,
                    port: port
                )
                logger.info("--- Successfully found NetworkInfo via discovery: \(String(describing: networkInfo)) ---")
                return networkInfo
            } catch {
                logger.debug("Failed to connect to discovered server \(service.name): \(error.localizedDescription)")
                continue
            }
        }
        
        // If no servers were found or none worked, throw an error
        if services.isEmpty {
            throw NSError(domain: "NetworkDiscovery", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "No SMB servers found on the network. Please try using Direct IP."])
        } else {
            throw NSError(domain: "NetworkDiscovery", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "Found servers but could not connect with provided credentials. Please verify username/password."])
        }
    } catch {
        logger.error("Server discovery failed: \(error.localizedDescription)")
        throw NSError(domain: "NetworkDiscovery", code: -4,
                      userInfo: [NSLocalizedDescriptionKey: "Failed to discover servers: \(error.localizedDescription)"])
    }
}


// MARK: - Connection Logic

private func attemptConnection(ipAddress: String, targetFolder: String, username: String, password: String, port: Int? = nil) async throws -> NetworkInfo {
    logger.info("Attempting SMB connection to Host/IP: \(ipAddress), Target Folder: '\(targetFolder)'")

    var components = URLComponents()
    components.scheme = "smb"
    components.host = ipAddress
    if let port = port {
        components.port = port
        logger.debug("Using explicit port: \(port)")
    }
    guard let serverURL = components.url else {
        logger.critical("Failed to create URL for host: \(ipAddress)")
        throw NSError(domain: "NetworkDiscovery", code: -15, userInfo: [NSLocalizedDescriptionKey: "Invalid server address: \(ipAddress)"])
    }

    logger.debug("Connecting to URL: \(serverURL.absoluteString)")

    guard let client = SMB2Manager(
        url: serverURL,
        credential: URLCredential(user: username, password: password, persistence: .forSession)
    ) else {
        logger.error("Failed to create SMB2Manager instance for \(serverURL.absoluteString)")
        throw NSError(domain: "NetworkDiscovery", code: -5,
                      userInfo: [NSLocalizedDescriptionKey: "Failed to create SMB client instance."])
    }

    // --- List Shares ---
    // Use a closure to connect, list shares, and disconnect, capturing the shares for later use.
    let availableShares = try await {
        logger.debug("Connecting to IPC$ on \(ipAddress)...")
        try await client.connectShare(name: "IPC$")
        logger.debug("Connected to IPC$. Listing shares...")
        let shares = try await client.listShares()
        logger.info("Found shares on \(ipAddress): \(shares.map { $0.name })")
        try await client.disconnectShare()
        logger.debug("Disconnected from IPC$.")
        return shares
    }()

    // --- Check if Target Folder is a Share Name ---
    let targetFolderLower = targetFolder.lowercased()
    if let matchingShare = availableShares.first(where: { $0.name.lowercased() == targetFolderLower }) {
            logger.info("Target '\(targetFolder)' matches a share name ('\(matchingShare.name)').")
            do {
                logger.debug("Testing connection to share '\(matchingShare.name)'...")
                try await client.connectShare(name: matchingShare.name)
            try await client.disconnectShare()
            logger.info("Successfully connected to share '\(matchingShare.name)'. Using it as base.")
            return NetworkInfo(serverIP: ipAddress, shareName: matchingShare.name, targetDirectory: nil)
        } catch {
            logger.warning("Target '\(targetFolder)' is a share name, but failed to connect directly: \(error.localizedDescription). Will check if it exists as a directory in other shares.")
        }
    } else {
         logger.debug("Target '\(targetFolder)' is not a direct share name.")
    }

    // --- Check if Target Folder Exists as a Directory Within Any Share ---
    let trimmedTarget = targetFolder.trimmingCharacters(in: CharacterSet(charactersIn: "/\\"))
    guard !trimmedTarget.isEmpty else {
        logger.error("Target folder name cannot be empty or just slashes.")
        throw NSError(domain: "NetworkDiscovery", code: -17, userInfo: [NSLocalizedDescriptionKey: "Target folder name is invalid."])
    }

    for share in availableShares {
        logger.debug("Checking share '\(share.name)' for directory '\(trimmedTarget)'...")
        do {
            try await client.connectShare(name: share.name)
            logger.debug("Connected to share '\(share.name)'. Attempting to list contents of path '\(trimmedTarget)'...")

            _ = try await client.contentsOfDirectory(atPath: trimmedTarget)

            logger.info("Successfully listed contents of directory '\(trimmedTarget)' within share '\(share.name)'. Directory exists.")
            try await client.disconnectShare()
            logger.debug("Disconnected from share '\(share.name)'.")
            return NetworkInfo(serverIP: ipAddress, shareName: share.name, targetDirectory: trimmedTarget)

        } catch let nsError as NSError where nsError.domain == NSPOSIXErrorDomain && nsError.code == ENOENT {
            logger.debug("Directory '\(trimmedTarget)' not found in share '\(share.name)'. (POSIX: ENOENT)")
            try? await client.disconnectShare()
            continue

        } catch let nsError as NSError where nsError.domain == "AMSMB2ErrorDomain" &&
            (nsError.code == 0x00000002 || nsError.code == 0xC0000034) {  // STATUS_OBJECT_NAME_NOT_FOUND || STATUS_OBJECT_PATH_NOT_FOUND
            logger.debug("Directory '\(trimmedTarget)' not found in share '\(share.name)'. (SMB Error: 0x\(String(format: "%08X", nsError.code)))")
            try? await client.disconnectShare()
            continue

        } catch let nsError as NSError where nsError.domain == "AMSMB2ErrorDomain" && nsError.code == 0xC0000103 {  // STATUS_NOT_A_DIRECTORY
            logger.warning("Path '\(trimmedTarget)' exists in share '\(share.name)', but it is not a directory.")
            try? await client.disconnectShare()
            continue

        } catch {
            logger.warning("Error checking share '\(share.name)' for directory '\(trimmedTarget)': \(error.localizedDescription)")
            try? await client.disconnectShare()
            continue
        }
    }

    // --- Target Not Found ---
    logger.error("Target folder '\(trimmedTarget)' not found as a share name or as an accessible directory within any share on server \(ipAddress)")
    throw NSError(domain: "NetworkDiscovery", code: -6,
                  userInfo: [NSLocalizedDescriptionKey: "Target folder '\(trimmedTarget)' not found in any accessible share on server \(ipAddress). Check the name and permissions."])
}


// MARK: - Bonjour Discovery (_smb._tcp)

extension NetworkDiscovery {
    func discoverSMBServers(timeout: TimeInterval) async throws -> [NetService] {
        return try await withCheckedThrowingContinuation { continuation in
            let browser = NetServiceBrowser()
            var discoveredServices: [NetService] = []
            var didResume = false

            let finish: (Result<[NetService], Error>) -> Void = { result in
                guard !didResume else { return }
                didResume = true
                switch result {
                case .success(let services):
                    continuation.resume(returning: services)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let delegate = BonjourDelegate(
                didFind: { service in
                    discoveredServices.append(service)
                },
                didRemove: { service in
                    discoveredServices.removeAll { $0 == service }
                },
                didComplete: {
                    finish(.success(discoveredServices))
                },
                didFail: { error in
                    finish(.failure(error))
                }
            )

            // Keep delegate alive
            objc_setAssociatedObject(browser, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)

            browser.delegate = delegate
            browser.searchForServices(ofType: "_smb._tcp.", inDomain: "local.")

            // Schedule search
            browser.schedule(in: .main, forMode: .common)

            // Set timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak browser] in
                browser?.stop()
                finish(.success(discoveredServices))
            }
        }
    }
    
    func resolveService(_ service: NetService) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = BonjourResolveDelegate(
                didResolve: { addresses in
                    if let ip = self.extractIPAddress(from: addresses) {
                        continuation.resume(returning: ip)
                    } else {
                        continuation.resume(throwing: NSError(domain: "NetworkDiscovery", code: -6,
                            userInfo: [NSLocalizedDescriptionKey: "Could not extract IP address from resolved service"]))
                    }
                },
                didFail: { error in
                    continuation.resume(throwing: error)
                }
            )
            
            // Keep delegate alive
            objc_setAssociatedObject(service, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            
            service.delegate = delegate
            service.resolve(withTimeout: 5.0)
        }
    }
    
    private func extractIPAddress(from addresses: [Data]) -> String? {
        for address in addresses {
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = address.withUnsafeBytes { pointer -> Int in
                guard let sockaddr = pointer.baseAddress?.assumingMemoryBound(to: sockaddr.self) else { return -1 }
                return Int(getnameinfo(
                    sockaddr,
                    socklen_t(address.count),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                ))
            }
            
            if result == 0 {
                return String(cString: hostname)
            }
        }
        return nil
    }
}

// MARK: - Bonjour Delegates
private class BonjourDelegate: NSObject, NetServiceBrowserDelegate {
    private let didFind: (NetService) -> Void
    private let didRemove: (NetService) -> Void
    private let didComplete: () -> Void
    private let didFail: (Error) -> Void
    
    init(didFind: @escaping (NetService) -> Void,
         didRemove: @escaping (NetService) -> Void,
         didComplete: @escaping () -> Void,
         didFail: @escaping (Error) -> Void) {
        self.didFind = didFind
        self.didRemove = didRemove
        self.didComplete = didComplete
        self.didFail = didFail
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        didFind(service)
        if !moreComing {
            didComplete()
        }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        didRemove(service)
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        didFail(NSError(domain: "NetworkDiscovery", code: -7,
                       userInfo: [NSLocalizedDescriptionKey: "Bonjour search failed: \(errorDict)"]))
    }
}

private class BonjourResolveDelegate: NSObject, NetServiceDelegate {
    private let didResolve: ([Data]) -> Void
    private let didFail: (Error) -> Void
    
    init(didResolve: @escaping ([Data]) -> Void,
         didFail: @escaping (Error) -> Void) {
        self.didResolve = didResolve
        self.didFail = didFail
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        if let addresses = sender.addresses {
            didResolve(addresses)
        } else {
            didFail(NSError(domain: "NetworkDiscovery", code: -8,
                           userInfo: [NSLocalizedDescriptionKey: "No addresses found for service"]))
        }
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        didFail(NSError(domain: "NetworkDiscovery", code: -9,
                       userInfo: [NSLocalizedDescriptionKey: "Failed to resolve service: \(errorDict)"]))
    }
}

