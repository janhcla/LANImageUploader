//
//  NetworkDiscovery.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 13/03/2025.
//
//  (Ensuring import is present, using types directly)
//

import Foundation
import AMSMB2    // <<<--- ENSURE THIS LINE IS PRESENT AND CORRECT
import Network   // Required for NetService, NetServiceBrowser, NWPathMonitor
import OSLog     // Use unified logging system

// Logger for this specific file/module
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NetworkDiscovery")

// NetworkInfo struct is defined in AppData.swift

// MARK: - Main Retrieval Function

internal func retrieveNetworkInfo(targetFolder: String, username: String, password: String, directIP: String? = nil, port: Int? = nil) async throws -> NetworkInfo {
    logger.info("--- Starting retrieveNetworkInfo ---")
    logger.debug("Target Folder: '\(targetFolder)', Username: '\(username)', DirectIP: \(directIP ?? "None"), Port: \(port?.description ?? "Default")")

    guard NetworkMonitor.shared.isConnected else {
        logger.error("Error: No network connection.")
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
    } else {
         logger.info("No Direct IP provided, proceeding with discovery.")
    }

    // --- Network Discovery ---
    logger.info("Starting network discovery...")
    let services: [NetService]
    do {
        services = try await discoverSMBServers(timeout: 10.0)
        logger.info("Discovery finished. Found \(services.count) services.")
     
            } catch {
                logger.error("Error during SMB service discovery: \(error.localizedDescription)")
                let nsError = error as NSError
                if nsError.domain == NetService.errorDomain {
                    throw NSError(domain: "NetworkDiscovery", code: nsError.code, userInfo: [NSLocalizedDescriptionKey: "Network discovery failed (\(nsError.code)). Check network settings and firewall. \(nsError.localizedDescription)"])
                } else {
                    throw error
                }
            }

            guard !services.isEmpty else {
                logger.error("Error: No SMB services found on the network.")
                throw NSError(domain: "NetworkDiscovery", code: -3,
                              userInfo: [NSLocalizedDescriptionKey: "No SMB servers found on the network. Ensure the server is on the same Wi-Fi, discoverable (check server's firewall/network settings), and Bonjour/mDNS is not blocked."])
            }

            // --- Attempt Connection to Discovered Services ---
            var lastError: Error?
            for service in services {
                logger.info("Processing discovered service: \(service.name)")
                do {
                    let resolvedHost = try await resolveService(service)
                    logger.info("Resolved service '\(service.name)' to host: \(resolvedHost)")

                    let networkInfo = try await attemptConnection(
                        ipAddress: resolvedHost,
                        targetFolder: targetFolder,
                        username: username,
                        password: password,
                        port: port
                    )

                    logger.info("--- Successfully found NetworkInfo via Discovery: \(String(describing: networkInfo)) ---")
                    return networkInfo

                } catch {
                    logger.warning("Attempt failed for service '\(service.name)': \(error.localizedDescription)")
                    lastError = error
                    continue
                }
            }

            // --- Failure ---
            logger.error("Error: Could not validate target folder '\(targetFolder)' on any discovered & accessible SMB server.")
            let errorMessage = lastError != nil ?
                "Could not find or access the target folder '\(targetFolder)' on any discovered SMB server. Last error: \(lastError!.localizedDescription)" :
                "Could not find or access the target folder '\(targetFolder)' on any discovered SMB server."

            throw NSError(domain: "NetworkDiscovery", code: -4,
                          userInfo: [NSLocalizedDescriptionKey: errorMessage])
        } // <- This closing brace should properly close the retrieveNetworkInfo function

        // MARK: - Connection Logic

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

public func discoverSMBServers(timeout: TimeInterval = 10.0) async throws -> [NetService] {
    logger.info("Starting discoverSMBServers with timeout: \(timeout)s")
    return try await withCheckedThrowingContinuation { continuation in
        let browser = NetServiceBrowser()
        let delegate = SMBServiceBrowserDelegate(continuation: continuation, browser: browser, timeout: timeout)
        browser.includesPeerToPeer = true
        browser.delegate = delegate
        logger.debug("Searching for services of type '_smb._tcp' in domain 'local.'")
        browser.searchForServices(ofType: "_smb._tcp", inDomain: "local.")
    }
}

// MARK: - Bonjour Browser Delegate

final class SMBServiceBrowserDelegate: NSObject, NetServiceBrowserDelegate {
    private let continuation: CheckedContinuation<[NetService], Error>
    private var foundServices: [NetService] = []
    private weak var browser: NetServiceBrowser?
    private var timer: Timer?
    private let timeout: TimeInterval
    private(set) var hasCompleted = false

    init(continuation: CheckedContinuation<[NetService], Error>, browser: NetServiceBrowser, timeout: TimeInterval) {
        self.continuation = continuation
        self.browser = browser
        self.timeout = timeout
        super.init()
        self.timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.handleTimeout()
        }
        logger.debug("SMBServiceBrowserDelegate initialized with timeout: \(self.timeout)s")
    }

    deinit {
        logger.debug("SMBServiceBrowserDelegate deinit")
        timer?.invalidate()
    }

    private func handleTimeout() {
        logger.warning("Discovery timed out after \(self.timeout) seconds.")
        stopAndComplete(with: foundServices, error: nil)
    }

    private func stopAndComplete(with services: [NetService], error: Error?) {
        guard !hasCompleted else {
            logger.debug("Attempted to complete discovery, but already completed.")
            return
        }
        hasCompleted = true
        logger.debug("Stopping timer and browser.")
        timer?.invalidate()
        browser?.stop()

        if let error = error {
            logger.error("Completing discovery with error: \(error.localizedDescription)")
            continuation.resume(throwing: error)
        } else {
            logger.info("Completing discovery successfully with \(services.count) services found.")
            continuation.resume(returning: services)
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        logger.info("Delegate: Found service: Name='\(service.name)', Domain='\(service.domain)', Type='\(service.type)', MoreComing=\(moreComing)")
        if !foundServices.contains(where: { $0.name == service.name && $0.domain == service.domain && $0.type == service.type }) {
             foundServices.append(service)
             logger.debug("Added service '\(service.name)' to found list.")
        } else {
             logger.debug("Service '\(service.name)' already in list, ignoring duplicate find.")
        }

        if !moreComing {
            logger.info("Delegate: No more services coming (didFind).")
            stopAndComplete(with: foundServices, error: nil)
        } else {
             logger.debug("Delegate: More services potentially coming...")
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        logger.info("Delegate: Removed service: Name='\(service.name)', MoreComing=\(moreComing)")
        if let index = foundServices.firstIndex(where: { $0.name == service.name && $0.domain == service.domain && $0.type == service.type }) {
            foundServices.remove(at: index)
            logger.debug("Removed service '\(service.name)' from found list.")
        }
        if !moreComing {
             logger.info("Delegate: No more services coming (didRemove).")
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        let errorCode = errorDict[NetService.errorCode]?.intValue ?? -1
        let nsError = NSError(domain: NetService.errorDomain, code: errorCode, userInfo: errorDict)
        logger.critical("Delegate: Did Not Search! Error: \(nsError.localizedDescription) (Code: \(errorCode))")
        stopAndComplete(with: [], error: nsError)
    }

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        logger.debug("Delegate: Browser Will Search...")
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        logger.debug("Delegate: Browser Did Stop Search.")
        if !hasCompleted {
             logger.warning("Delegate: Search stopped unexpectedly. Completing with current findings.")
             stopAndComplete(with: foundServices, error: nil)
        }
    }
}

// MARK: - Bonjour Service Resolution

public func resolveService(_ service: NetService, timeout: TimeInterval = 5.0) async throws -> String {
    logger.info("Resolving service: '\(service.name)' with timeout \(timeout)s...")
    return try await withCheckedThrowingContinuation { continuation in
        let delegate = NetServiceResolveDelegate(continuation: continuation, service: service, timeout: timeout)
        service.delegate = delegate
        logger.debug("Calling service.resolve(withTimeout: \(timeout)) for '\(service.name)'")
        service.resolve(withTimeout: timeout)
    }
}

// MARK: - Bonjour Resolve Delegate

final class NetServiceResolveDelegate: NSObject, NetServiceDelegate {
    private let continuation: CheckedContinuation<String, Error>
    private weak var service: NetService?
    private var timer: Timer?
    private let timeout: TimeInterval
    private var hasCompleted = false

    init(continuation: CheckedContinuation<String, Error>, service: NetService, timeout: TimeInterval) {
        self.continuation = continuation
        self.service = service
        self.timeout = timeout
        super.init()
        self.timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.handleTimeout()
        }
        logger.debug("NetServiceResolveDelegate initialized for '\(self.service?.name ?? "unknown")' with timeout: \(self.timeout)s")
    }

     deinit {
        logger.debug("NetServiceResolveDelegate deinit for '\(self.service?.name ?? "unknown")'")
        timer?.invalidate()
    }

    private func handleTimeout() {
        logger.error("Resolve timed out for service '\(self.service?.name ?? "unknown")' after \(self.timeout)s.")
        complete(with: nil, error: NSError(domain: "NetworkDiscovery", code: -8, userInfo: [NSLocalizedDescriptionKey: "Resolving service '\(self.service?.name ?? "unknown")' timed out (\(self.timeout)s)."]))
    }

    private func complete(with result: String?, error: Error?) {
        guard !hasCompleted else {
             logger.debug("Attempted to complete resolve for '\(self.service?.name ?? "unknown")', but already completed.")
             return
        }
        hasCompleted = true
        logger.debug("Stopping timer and service resolve for '\(self.service?.name ?? "unknown")'.")
        timer?.invalidate()
        service?.stop()

        if let error = error {
            logger.error("Completing resolve for '\(self.service?.name ?? "unknown")' with error: \(error.localizedDescription)")
            continuation.resume(throwing: error)
        } else if let result = result {
            logger.info("Completing resolve for '\(self.service?.name ?? "unknown")' successfully with result: \(result)")
            continuation.resume(returning: result)
        } else {
             let fallbackError = NSError(domain: "NetworkDiscovery", code: -9, userInfo: [NSLocalizedDescriptionKey: "Resolve completed without result or error for service '\(self.service?.name ?? "unknown")'. Internal error."])
             logger.critical("Completing resolve for '\(self.service?.name ?? "unknown")' with fallback error.")
             continuation.resume(throwing: fallbackError)
        }
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        logger.info("Delegate: Did Resolve Address for '\(sender.name)'")

        if let hostName = sender.hostName, !hostName.isEmpty {
            logger.info("Resolved to hostName: \(hostName)")
            let cleanHostName = hostName.replacingOccurrences(of: ".local.", with: "")
            complete(with: cleanHostName, error: nil)
            return
        }

        logger.warning("Delegate: hostName is nil or empty for '\(sender.name)', trying to extract IP from addresses.")
        if let addresses = sender.addresses {
            for addressData in addresses {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let success = addressData.withUnsafeBytes { ptr -> Bool in
                    guard let sockaddr_ptr = ptr.baseAddress?.assumingMemoryBound(to: sockaddr.self) else { return false }
                    if sockaddr_ptr.pointee.sa_family == AF_INET {
                        return getnameinfo(sockaddr_ptr, socklen_t(addressData.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0
                    }
                    return false
                }

                if success {
                    let ipAddress = String(cString: hostname)
                    logger.info("Resolved IP (v4) from address data: \(ipAddress)")
                    complete(with: ipAddress, error: nil)
                    return
                }
            }
        }

        logger.error("Delegate: Did Resolve Address called but no hostName or usable IPv4 address found for '\(sender.name)'.")
        complete(with: nil, error: NSError(domain: "NetworkDiscovery", code: -13, userInfo: [NSLocalizedDescriptionKey: "Resolved service '\(sender.name)' but could not extract hostname or a valid IPv4 address."]))
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        let errorCode = errorDict[NetService.errorCode]?.intValue ?? -1
        let nsError = NSError(domain: NetService.errorDomain, code: errorCode, userInfo: errorDict)
        logger.error("Delegate: Did Not Resolve '\(sender.name)'. Error: \(nsError.localizedDescription) (Code: \(errorCode))")
        complete(with: nil, error: nsError)
    }

     func netServiceDidStop(_ sender: NetService) {
         logger.debug("Delegate: Service '\(sender.name)' Did Stop resolving.")
         if !hasCompleted {
             logger.warning("Delegate: Resolve for '\(sender.name)' stopped unexpectedly.")
             self.complete(with: nil, error: NSError(domain: "NetworkDiscovery", code: -14, userInfo: [NSLocalizedDescriptionKey: "Service '\(sender.name)' stopped resolving unexpectedly."]))
         }
     }
}
