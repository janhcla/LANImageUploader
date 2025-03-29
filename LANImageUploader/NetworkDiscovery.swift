//
//  NetworkDiscovery.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 13/03/2025.
//

import Foundation
import Network   // Required for NetService, NetServiceBrowser, NWPathMonitor
import OSLog     // Use unified logging system
import AMSMB2    // Required for SMB functionality

// Logger for this specific file/module
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NetworkDiscovery")

// MARK: - Main Class Definition
@MainActor
final class NetworkDiscovery {
    static let shared = NetworkDiscovery()
    private init() {}
    
    private var discoveredServersCache: [String: (timestamp: Date, info: NetworkInfo)] = [:]
    private let cacheDuration: TimeInterval = 300
}

// MARK: - Main Retrieval Function
extension NetworkDiscovery {
    internal func retrieveNetworkInfo(targetFolder: String, username: String, password: String, directIP: String? = nil, port: Int? = nil) async throws -> NetworkInfo {
        logger.info("--- Starting retrieveNetworkInfo ---")
        logger.debug("Target Folder: '\(targetFolder)', Username: '\(username)', DirectIP: \(directIP ?? "None"), Port: \(port?.description ?? "Default")")
        
        // CHANGE: Remove 'await' as NetworkMonitor.shared.isConnected is not async
        guard NetworkMonitor.shared.isConnected else {
            logger.error("Network connection unavailable.")
            throw NSError(domain: "NetworkDiscovery", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "No network connection available. Please check your Wi-Fi connection."])
        }
        
        // Check cache for direct IP
        if let directIP = directIP, !directIP.isEmpty {
            if let cachedInfo = getCachedServer(directIP) {
                logger.info("Using cached server information for \(directIP)")
                return cachedInfo
            }
            
            logger.info("Attempting direct connection to IP: \(directIP) with Port: \(port?.description ?? "Default")")
            do {
                let networkInfo = try await attemptConnection(
                    ipAddress: directIP,
                    targetFolder: targetFolder,
                    username: username,
                    password: password,
                    port: port
                )
                logger.info("Successfully connected to direct IP: \(directIP)")
                cacheServer(networkInfo)
                return networkInfo
            } catch {
                logger.warning("Direct IP (\(directIP)) connection failed: \(error.localizedDescription). Falling back to discovery.")
            }
        }
        
        // Start with fast subnet scan
        logger.info("Starting fast subnet scan...")
        let scanStartTime = Date()
        
        if let foundIP = try await fastSubnetScan(batchSize: 25) {
            let scanDuration = Date().timeIntervalSince(scanStartTime)
            logger.info("Found server at IP \(foundIP) in \(String(format: "%.2f", scanDuration)) seconds")
            
            let networkInfo = try await attemptConnection(
                ipAddress: foundIP,
                targetFolder: targetFolder,
                username: username,
                password: password,
                port: port
            )
            cacheServer(networkInfo)
            return networkInfo
        }
        
        // Fall back to Bonjour discovery if fast scan fails
        logger.info("Starting Bonjour discovery for SMB servers...")
        do {
            let services = try await discoverSMBServers(timeout: 5.0)
            logger.info("Found \(services.count) SMB services")
            
            for service in services {
                do {
                    let serverIP = try await resolveService(service)
                    logger.info("Attempting connection to discovered server: \(serverIP)")
                    
                    let networkInfo = try await attemptConnection(
                        ipAddress: serverIP,
                        targetFolder: targetFolder,
                        username: username,
                        password: password,
                        port: port
                    )
                    logger.info("Successfully connected to discovered server: \(serverIP)")
                    cacheServer(networkInfo)
                    return networkInfo
                } catch {
                    logger.debug("Failed to connect to discovered server \(service.name): \(error.localizedDescription)")
                    continue
                }
            }
            
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
}

// MARK: - Fast Subnet Scanning
extension NetworkDiscovery {
    private func fastSubnetScan(startIP: Int = 1, batchSize: Int = 25) async throws -> String? {
        let currentIP = await getCurrentDeviceIP() ?? "192.168.1.1"
        let subnet = currentIP.split(separator: ".").dropLast().joined(separator: ".")
        
        let totalIPs = 254
        var currentStart = startIP
        
        while currentStart <= totalIPs {
            let endIP = min(currentStart + batchSize - 1, totalIPs)
            
            if let foundIP = try await withThrowingTaskGroup(of: String?.self, body: { group -> String? in
                for i in currentStart...endIP {
                    group.addTask {
                        let ip = "\(subnet).\(i)"
                        if try await self.quickPortCheck(ip: ip, port: 445, timeout: 0.1) {
                            return ip
                        }
                        return nil
                    }
                }
                
                for try await result in group {
                    if let ip = result {
                        group.cancelAll()
                        return ip
                    }
                }
                return nil
            }) {
                return foundIP
            }
            
            currentStart += batchSize
        }
        return nil
    }

    private func quickPortCheck(ip: String, port: Int, timeout: TimeInterval) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            let queue = DispatchQueue.global(qos: .userInitiated)
            
            queue.async {
                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = UInt16(port).bigEndian
                guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else {
                    continuation.resume(returning: false)
                    return
                }
                
                let sock = socket(AF_INET, SOCK_STREAM, 0)
                guard sock != -1 else {
                    continuation.resume(returning: false)
                    return
                }
                
                // CHANGE: Change var to let and handle fcntl result
                let flags = fcntl(sock, F_GETFL, 0)
                let setResult = fcntl(sock, F_SETFL, flags | O_NONBLOCK)
                if setResult == -1 {
                    logger.error("Failed to set socket to non-blocking mode: \(errno)")
                    close(sock)
                    continuation.resume(returning: false)
                    return
                }
                
                let result = withUnsafePointer(to: addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
                
                if result == 0 {
                    close(sock)
                    continuation.resume(returning: true)
                    return
                }
                
                var fds = pollfd(fd: sock, events: Int16(POLLOUT), revents: 0)
                let pollResult = poll(&fds, 1, Int32(timeout * 1000))
                
                close(sock)
                continuation.resume(returning: pollResult == 1 && (fds.revents & Int16(POLLOUT)) != 0)
            }
        }
    }
    
    private func getCurrentDeviceIP() async -> String? {
        var address: String?
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            let interface = ptr?.pointee
            let addrFamily = interface?.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: (interface?.ifa_name)!)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface?.ifa_addr,
                               socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                               &hostname,
                               socklen_t(hostname.count),
                               nil,
                               0,
                               NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        return address
    }
}

// MARK: - Server Cache Management
extension NetworkDiscovery {
    private func cacheServer(_ info: NetworkInfo) {
        discoveredServersCache[info.serverIP] = (Date(), info)
    }
    
    private func getCachedServer(_ ip: String) -> NetworkInfo? {
        guard let (timestamp, info) = discoveredServersCache[ip] else { return nil }
        guard Date().timeIntervalSince(timestamp) < cacheDuration else {
            discoveredServersCache.removeValue(forKey: ip)
            return nil
        }
        return info
    }
}

// MARK: - Bonjour Discovery (_smb._tcp)
extension NetworkDiscovery {
    @MainActor
    func discoverSMBServers(timeout: TimeInterval) async throws -> [NetService] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[NetService], Error>) in
            let browser = NetServiceBrowser()
            var discoveredServices: [NetService] = []
            // REMOVE: Unused syncQueue
            var didResume = false
            var attemptedConnections = Set<String>()
            
            let finish: @Sendable (Result<[NetService], Error>) -> Void = { result in
                Task { @MainActor in
                    guard !didResume else { return }
                    didResume = true
                    switch result {
                    case .success(let services):
                        let sortedServices = services.sorted { $0.name.lowercased() < $1.name.lowercased() }
                        continuation.resume(returning: sortedServices)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            let delegate = BonjourDelegate(
                // CHANGE: Remove unnecessary weak capture of browser
                didFind: { service in
                    Task { @MainActor in
                        guard !attemptedConnections.contains(service.name) else { return }
                        attemptedConnections.insert(service.name)
                        service.resolve(withTimeout: 2.0)
                        discoveredServices.append(service)
                    }
                },
                didRemove: { service in
                    Task { @MainActor in
                        discoveredServices.removeAll { $0.name == service.name }
                        attemptedConnections.remove(service.name)
                    }
                },
                didComplete: {
                    Task { @MainActor in
                        finish(.success(discoveredServices))
                    }
                },
                didFail: { error in
                    Task { @MainActor in
                        finish(.failure(error))
                    }
                }
            )
            
            objc_setAssociatedObject(browser, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            
            browser.delegate = delegate
            
            let serviceTypes = ["_smb._tcp.", "_microsoft-ds._tcp."]
            for serviceType in serviceTypes {
                browser.searchForServices(ofType: serviceType, inDomain: "local.")
            }
            
            browser.schedule(in: .main, forMode: .common)
            
            let shortTimeout = min(timeout * 0.5, 2.0)
            Task { @MainActor in
                try await Task.sleep(nanoseconds: UInt64(shortTimeout * 1_000_000_000))
                if !discoveredServices.isEmpty {
                    finish(.success(discoveredServices))
                }
            }
            
            Task { @MainActor in
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                browser.stop()
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
            
            objc_setAssociatedObject(service, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            
            service.delegate = delegate
            service.resolve(withTimeout: 2.0)
        }
    }
    
    private func extractIPAddress(from addresses: [Data]) -> String? {
        enum AddressPreference {
            case ipv4
            case ipv6
            
            var family: Int32 {
                switch self {
                case .ipv4: return AF_INET
                case .ipv6: return AF_INET6
                }
            }
        }
        
        let preferences: [AddressPreference] = [.ipv4, .ipv6]
        
        for preference in preferences {
            for address in addresses {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                
                let result = address.withUnsafeBytes { pointer -> Int32 in
                    guard let sockaddr = pointer.baseAddress?.assumingMemoryBound(to: sockaddr.self) else { return -1 }
                    
                    let family = Int32(sockaddr.pointee.sa_family)
                    guard family == preference.family else { return -1 }

                    return getnameinfo(
                                            sockaddr,
                                            socklen_t(address.count),
                                            &hostname,
                                            socklen_t(hostname.count),
                                            nil,
                                            0,
                                            NI_NUMERICHOST | NI_NUMERICSERV
                                        )
                                    }
                                    
                                    if result == 0 {
                                        let ip = String(cString: hostname)
                                        if !ip.hasPrefix("fe80:") && !ip.hasPrefix("169.254.") {
                                            return ip
                                        }
                                    }
                                }
                            }
                            return nil
                        }
                    }

                    // MARK: - Connection Logic
                    extension NetworkDiscovery {
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
                            
                            // List shares
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
                            
                            // Check if Target Folder is a Share Name
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
                            
                            // Check if Target Folder exists as a Directory Within Any Share
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
                                    (nsError.code == 0x00000002 || nsError.code == 0xC0000034) {
                                    logger.debug("Directory '\(trimmedTarget)' not found in share '\(share.name)'. (SMB Error: 0x\(String(format: "%08X", nsError.code)))")
                                    try? await client.disconnectShare()
                                    continue
                                    
                                } catch let nsError as NSError where nsError.domain == "AMSMB2ErrorDomain" && nsError.code == 0xC0000103 {
                                    logger.warning("Path '\(trimmedTarget)' exists in share '\(share.name)', but it is not a directory.")
                                    try? await client.disconnectShare()
                                    continue
                                    
                                } catch {
                                    logger.warning("Error checking share '\(share.name)' for directory '\(trimmedTarget)': \(error.localizedDescription)")
                                    try? await client.disconnectShare()
                                    continue
                                }
                            }
                            
                            logger.error("Target folder '\(trimmedTarget)' not found as a share name or as an accessible directory within any share on server \(ipAddress)")
                            throw NSError(domain: "NetworkDiscovery", code: -6,
                                         userInfo: [NSLocalizedDescriptionKey: "Target folder '\(trimmedTarget)' not found in any accessible share on server \(ipAddress). Check the name and permissions."])
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

////
////  NetworkDiscovery.swift
////  LANImageUploader
////
////  Created by Jan Hagen Clausen on 13/03/2025.
////
////  (Ensuring import is present, using types directly)
////
//
//import Foundation
//import Network   // Required for NetService, NetServiceBrowser, NWPathMonitor
//import OSLog     // Use unified logging system
//import AMSMB2    // Required for SMB functionality
//
//// Logger for this specific file/module
//private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NetworkDiscovery")
//
//// NetworkInfo struct is defined in AppData.swift
//
//// Add NetworkDiscovery class definition before the extension
//final class NetworkDiscovery {
//    static let shared = NetworkDiscovery()
//    private init() {}
//}
//
//// MARK: - Main Retrieval Function
//
//internal func retrieveNetworkInfo(targetFolder: String, username: String, password: String, directIP: String? = nil, port: Int? = nil) async throws -> NetworkInfo {
//    logger.info("--- Starting retrieveNetworkInfo ---")
//    logger.debug("Target Folder: '\(targetFolder)', Username: '\(username)', DirectIP: \(directIP ?? "None"), Port: \(port?.description ?? "Default")")
//
//    // Check network connectivity directly rather than waiting
//    guard await NetworkMonitor.shared.isConnected else {
//        logger.error("Network connection unavailable.")
//        throw NSError(domain: "NetworkDiscovery", code: -1,
//                      userInfo: [NSLocalizedDescriptionKey: "No network connection available. Please check your Wi-Fi connection."])
//    }
//
//    // --- Direct IP Attempt (If Provided) ---
//    if let directIP = directIP, !directIP.isEmpty {
//        logger.info("Attempting direct connection to IP: \(directIP) with Port: \(port?.description ?? "Default")")
//        do {
//            let networkInfo = try await attemptConnection(
//                ipAddress: directIP,
//                targetFolder: targetFolder,
//                username: username,
//                password: password,
//                port: port
//            )
//            logger.info("--- Successfully found NetworkInfo via Direct IP: \(String(describing: networkInfo)) ---")
//            return networkInfo
//        } catch {
//            logger.warning("Direct IP (\(directIP)) connection failed: \(error.localizedDescription). Falling back to discovery.")
//        }
//    }
//
//    // --- Network Discovery using Bonjour ---
//    logger.info("Starting Bonjour discovery for SMB servers...")
//    
//    do {
//        // Discover SMB servers using Bonjour
//        let services = try await NetworkDiscovery.shared.discoverSMBServers(timeout: 5.0)
//        logger.info("Found \(services.count) SMB services")
//        
//        // Try each discovered server
//        for service in services {
//            do {
//                let serverIP = try await NetworkDiscovery.shared.resolveService(service)
//                logger.info("Attempting connection to discovered server: \(serverIP)")
//                
//                let networkInfo = try await attemptConnection(
//                    ipAddress: serverIP,
//                    targetFolder: targetFolder,
//                    username: username,
//                    password: password,
//                    port: port
//                )
//                logger.info("--- Successfully found NetworkInfo via discovery: \(String(describing: networkInfo)) ---")
//                return networkInfo
//            } catch {
//                logger.debug("Failed to connect to discovered server \(service.name): \(error.localizedDescription)")
//                continue
//            }
//        }
//        
//        // If no servers were found or none worked, throw an error
//        if services.isEmpty {
//            throw NSError(domain: "NetworkDiscovery", code: -2,
//                          userInfo: [NSLocalizedDescriptionKey: "No SMB servers found on the network. Please try using Direct IP."])
//        } else {
//            throw NSError(domain: "NetworkDiscovery", code: -3,
//                          userInfo: [NSLocalizedDescriptionKey: "Found servers but could not connect with provided credentials. Please verify username/password."])
//        }
//    } catch {
//        logger.error("Server discovery failed: \(error.localizedDescription)")
//        throw NSError(domain: "NetworkDiscovery", code: -4,
//                      userInfo: [NSLocalizedDescriptionKey: "Failed to discover servers: \(error.localizedDescription)"])
//    }
//}
//
//
//// MARK: - Connection Logic
//
//private func attemptConnection(ipAddress: String, targetFolder: String, username: String, password: String, port: Int? = nil) async throws -> NetworkInfo {
//    logger.info("Attempting SMB connection to Host/IP: \(ipAddress), Target Folder: '\(targetFolder)'")
//
//    var components = URLComponents()
//    components.scheme = "smb"
//    components.host = ipAddress
//    if let port = port {
//        components.port = port
//        logger.debug("Using explicit port: \(port)")
//    }
//    guard let serverURL = components.url else {
//        logger.critical("Failed to create URL for host: \(ipAddress)")
//        throw NSError(domain: "NetworkDiscovery", code: -15, userInfo: [NSLocalizedDescriptionKey: "Invalid server address: \(ipAddress)"])
//    }
//
//    logger.debug("Connecting to URL: \(serverURL.absoluteString)")
//
//    guard let client = SMB2Manager(
//        url: serverURL,
//        credential: URLCredential(user: username, password: password, persistence: .forSession)
//    ) else {
//        logger.error("Failed to create SMB2Manager instance for \(serverURL.absoluteString)")
//        throw NSError(domain: "NetworkDiscovery", code: -5,
//                      userInfo: [NSLocalizedDescriptionKey: "Failed to create SMB client instance."])
//    }
//
//    // --- List Shares ---
//    // Use a closure to connect, list shares, and disconnect, capturing the shares for later use.
//    let availableShares = try await {
//        logger.debug("Connecting to IPC$ on \(ipAddress)...")
//        try await client.connectShare(name: "IPC$")
//        logger.debug("Connected to IPC$. Listing shares...")
//        let shares = try await client.listShares()
//        logger.info("Found shares on \(ipAddress): \(shares.map { $0.name })")
//        try await client.disconnectShare()
//        logger.debug("Disconnected from IPC$.")
//        return shares
//    }()
//
//    // --- Check if Target Folder is a Share Name ---
//    let targetFolderLower = targetFolder.lowercased()
//    if let matchingShare = availableShares.first(where: { $0.name.lowercased() == targetFolderLower }) {
//            logger.info("Target '\(targetFolder)' matches a share name ('\(matchingShare.name)').")
//            do {
//                logger.debug("Testing connection to share '\(matchingShare.name)'...")
//                try await client.connectShare(name: matchingShare.name)
//            try await client.disconnectShare()
//            logger.info("Successfully connected to share '\(matchingShare.name)'. Using it as base.")
//            return NetworkInfo(serverIP: ipAddress, shareName: matchingShare.name, targetDirectory: nil)
//        } catch {
//            logger.warning("Target '\(targetFolder)' is a share name, but failed to connect directly: \(error.localizedDescription). Will check if it exists as a directory in other shares.")
//        }
//    } else {
//         logger.debug("Target '\(targetFolder)' is not a direct share name.")
//    }
//
//    // --- Check if Target Folder Exists as a Directory Within Any Share ---
//    let trimmedTarget = targetFolder.trimmingCharacters(in: CharacterSet(charactersIn: "/\\"))
//    guard !trimmedTarget.isEmpty else {
//        logger.error("Target folder name cannot be empty or just slashes.")
//        throw NSError(domain: "NetworkDiscovery", code: -17, userInfo: [NSLocalizedDescriptionKey: "Target folder name is invalid."])
//    }
//
//    for share in availableShares {
//        logger.debug("Checking share '\(share.name)' for directory '\(trimmedTarget)'...")
//        do {
//            try await client.connectShare(name: share.name)
//            logger.debug("Connected to share '\(share.name)'. Attempting to list contents of path '\(trimmedTarget)'...")
//
//            _ = try await client.contentsOfDirectory(atPath: trimmedTarget)
//
//            logger.info("Successfully listed contents of directory '\(trimmedTarget)' within share '\(share.name)'. Directory exists.")
//            try await client.disconnectShare()
//            logger.debug("Disconnected from share '\(share.name)'.")
//            return NetworkInfo(serverIP: ipAddress, shareName: share.name, targetDirectory: trimmedTarget)
//
//        } catch let nsError as NSError where nsError.domain == NSPOSIXErrorDomain && nsError.code == ENOENT {
//            logger.debug("Directory '\(trimmedTarget)' not found in share '\(share.name)'. (POSIX: ENOENT)")
//            try? await client.disconnectShare()
//            continue
//
//        } catch let nsError as NSError where nsError.domain == "AMSMB2ErrorDomain" &&
//            (nsError.code == 0x00000002 || nsError.code == 0xC0000034) {  // STATUS_OBJECT_NAME_NOT_FOUND || STATUS_OBJECT_PATH_NOT_FOUND
//            logger.debug("Directory '\(trimmedTarget)' not found in share '\(share.name)'. (SMB Error: 0x\(String(format: "%08X", nsError.code)))")
//            try? await client.disconnectShare()
//            continue
//
//        } catch let nsError as NSError where nsError.domain == "AMSMB2ErrorDomain" && nsError.code == 0xC0000103 {  // STATUS_NOT_A_DIRECTORY
//            logger.warning("Path '\(trimmedTarget)' exists in share '\(share.name)', but it is not a directory.")
//            try? await client.disconnectShare()
//            continue
//
//        } catch {
//            logger.warning("Error checking share '\(share.name)' for directory '\(trimmedTarget)': \(error.localizedDescription)")
//            try? await client.disconnectShare()
//            continue
//        }
//    }
//
//    // --- Target Not Found ---
//    logger.error("Target folder '\(trimmedTarget)' not found as a share name or as an accessible directory within any share on server \(ipAddress)")
//    throw NSError(domain: "NetworkDiscovery", code: -6,
//                  userInfo: [NSLocalizedDescriptionKey: "Target folder '\(trimmedTarget)' not found in any accessible share on server \(ipAddress). Check the name and permissions."])
//}
//
//
//// MARK: - Bonjour Discovery (_smb._tcp)
//
//extension NetworkDiscovery {
//    func discoverSMBServers(timeout: TimeInterval) async throws -> [NetService] {
//        return try await withCheckedThrowingContinuation { continuation in
//            let browser = NetServiceBrowser()
//            var discoveredServices: [NetService] = []
//            var didResume = false
//
//            let finish: (Result<[NetService], Error>) -> Void = { result in
//                guard !didResume else { return }
//                didResume = true
//                switch result {
//                case .success(let services):
//                    continuation.resume(returning: services)
//                case .failure(let error):
//                    continuation.resume(throwing: error)
//                }
//            }
//
//            let delegate = BonjourDelegate(
//                didFind: { service in
//                    discoveredServices.append(service)
//                },
//                didRemove: { service in
//                    discoveredServices.removeAll { $0 == service }
//                },
//                didComplete: {
//                    finish(.success(discoveredServices))
//                },
//                didFail: { error in
//                    finish(.failure(error))
//                }
//            )
//
//            // Keep delegate alive
//            objc_setAssociatedObject(browser, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
//
//            browser.delegate = delegate
//            browser.searchForServices(ofType: "_smb._tcp.", inDomain: "local.")
//
//            // Schedule search
//            browser.schedule(in: .main, forMode: .common)
//
//            // Set timeout
//            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak browser] in
//                browser?.stop()
//                finish(.success(discoveredServices))
//            }
//        }
//    }
//    
//    func resolveService(_ service: NetService) async throws -> String {
//        return try await withCheckedThrowingContinuation { continuation in
//            let delegate = BonjourResolveDelegate(
//                didResolve: { addresses in
//                    if let ip = self.extractIPAddress(from: addresses) {
//                        continuation.resume(returning: ip)
//                    } else {
//                        continuation.resume(throwing: NSError(domain: "NetworkDiscovery", code: -6,
//                            userInfo: [NSLocalizedDescriptionKey: "Could not extract IP address from resolved service"]))
//                    }
//                },
//                didFail: { error in
//                    continuation.resume(throwing: error)
//                }
//            )
//            
//            // Keep delegate alive
//            objc_setAssociatedObject(service, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
//            
//            service.delegate = delegate
//            service.resolve(withTimeout: 5.0)
//        }
//    }
//    
//    private func extractIPAddress(from addresses: [Data]) -> String? {
//        for address in addresses {
//            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
//            let result = address.withUnsafeBytes { pointer -> Int in
//                guard let sockaddr = pointer.baseAddress?.assumingMemoryBound(to: sockaddr.self) else { return -1 }
//                return Int(getnameinfo(
//                    sockaddr,
//                    socklen_t(address.count),
//                    &hostname,
//                    socklen_t(hostname.count),
//                    nil,
//                    0,
//                    NI_NUMERICHOST
//                ))
//            }
//            
//            if result == 0 {
//                return String(cString: hostname)
//            }
//        }
//        return nil
//    }
//}
//
//// MARK: - Bonjour Delegates
//private class BonjourDelegate: NSObject, NetServiceBrowserDelegate {
//    private let didFind: (NetService) -> Void
//    private let didRemove: (NetService) -> Void
//    private let didComplete: () -> Void
//    private let didFail: (Error) -> Void
//    
//    init(didFind: @escaping (NetService) -> Void,
//         didRemove: @escaping (NetService) -> Void,
//         didComplete: @escaping () -> Void,
//         didFail: @escaping (Error) -> Void) {
//        self.didFind = didFind
//        self.didRemove = didRemove
//        self.didComplete = didComplete
//        self.didFail = didFail
//    }
//    
//    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
//        didFind(service)
//        if !moreComing {
//            didComplete()
//        }
//    }
//    
//    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
//        didRemove(service)
//    }
//    
//    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
//        didFail(NSError(domain: "NetworkDiscovery", code: -7,
//                       userInfo: [NSLocalizedDescriptionKey: "Bonjour search failed: \(errorDict)"]))
//    }
//}
//
//private class BonjourResolveDelegate: NSObject, NetServiceDelegate {
//    private let didResolve: ([Data]) -> Void
//    private let didFail: (Error) -> Void
//    
//    init(didResolve: @escaping ([Data]) -> Void,
//         didFail: @escaping (Error) -> Void) {
//        self.didResolve = didResolve
//        self.didFail = didFail
//    }
//    
//    func netServiceDidResolveAddress(_ sender: NetService) {
//        if let addresses = sender.addresses {
//            didResolve(addresses)
//        } else {
//            didFail(NSError(domain: "NetworkDiscovery", code: -8,
//                           userInfo: [NSLocalizedDescriptionKey: "No addresses found for service"]))
//        }
//    }
//    
//    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
//        didFail(NSError(domain: "NetworkDiscovery", code: -9,
//                       userInfo: [NSLocalizedDescriptionKey: "Failed to resolve service: \(errorDict)"]))
//    }
//}
//
