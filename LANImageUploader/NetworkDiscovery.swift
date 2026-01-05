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
import Darwin
import SwiftUI

// Logger for this specific file/module
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NetworkDiscovery")

public enum ConnectionError: LocalizedError, Equatable, Sendable {
    case authenticationFailed
    case hostNotFound(String)
    case shareNotFound(String)
    case folderNotFound(String)
    case timeout
    case cancelled
    case networkUnavailable
    case noHostsFound
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed. Please check your username and password."
        case .hostNotFound(let host):
            return "Host '\(host)' could not be found."
        case .shareNotFound(let share):
            return "Share '\(share)' does not exist on the server."
        case .folderNotFound(let folder):
            return "Folder '\(folder)' could not be found."
        case .timeout:
            return "Connection timed out."
        case .cancelled:
            return "Connection cancelled by user."
        case .networkUnavailable:
            return "No network connection available."
        case .noHostsFound:
            return "No SMB servers found on the network."
        case .unknown(let message):
            return "An unknown error occurred: \(message)"
        }
    }
}

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
    internal func retrieveNetworkInfo(
        targetFolder: String,
        username: String,
        password: String,
        directIP: String? = nil,
        port: Int? = nil,
        onStatus: (@Sendable (ConnectionStatus) -> Void)? = nil
    ) async throws -> NetworkInfo {
        logger.info("--- Starting retrieveNetworkInfo ---")
        
        // Wait briefly for network monitor to be ready
        if try await !NetworkMonitor.shared.waitForNetwork(timeout: 1.0) {
            logger.error("Network connection unavailable (timed out waiting).")
            let error = ConnectionError.networkUnavailable
            onStatus?(.failure(error))
            throw error
        }
        
        // 1. Direct Connection Attempt
        if let directIP = directIP, !directIP.isEmpty {
            onStatus?(.connecting(directIP))
            if let cachedInfo = getCachedServer(directIP) {
                logger.info("Using cached server information for \(directIP)")
                onStatus?(.connected(cachedInfo))
                return cachedInfo
            }
            
            do {
                let networkInfo = try await attemptConnection(
                    ipAddress: directIP,
                    targetFolder: targetFolder,
                    username: username,
                    password: password,
                    port: port,
                    onStatus: onStatus
                )
                cacheServer(networkInfo)
                onStatus?(.connected(networkInfo))
                return networkInfo
            } catch {
                logger.warning("Direct IP (\(directIP)) connection failed: \(error.localizedDescription). Falling back to discovery.")
            }
        }
        
        // 2. Fast Subnet Scan
        try Task.checkCancellation()
        onStatus?(.discovery(.subnetScan(progress: 0.0)))
        logger.info("Starting fast subnet scan...")
        
        let foundIPs = try await fastSubnetScan(batchSize: 25, onProgress: { progress in
            onStatus?(.discovery(.subnetScan(progress: progress)))
        })
        
        if let foundIP = foundIPs.first {
            onStatus?(.connecting(foundIP))
            let networkInfo = try await attemptConnection(
                ipAddress: foundIP,
                targetFolder: targetFolder,
                username: username,
                password: password,
                port: port,
                onStatus: onStatus
            )
            cacheServer(networkInfo)
            onStatus?(.connected(networkInfo))
            return networkInfo
        }
        
        // 3. Bonjour Discovery with Retry
        try Task.checkCancellation()
        onStatus?(.discovery(.bonjourSearch))
        var retryCount = 0
        let maxRetries = 2
        
        while retryCount <= maxRetries {
            try Task.checkCancellation()
            logger.info("Starting Bonjour discovery (attempt \(retryCount + 1))...")
            do {
                let services = try await discoverSMBServers(timeout: 5.0)
                logger.info("Found \(services.count) SMB services")
                
                for service in services {
                    try Task.checkCancellation()
                    onStatus?(.discovery(.resolving(service.name)))
                    do {
                        let serverIP = try await resolveService(service)
                        onStatus?(.connecting(serverIP))
                        
                        let networkInfo = try await attemptConnection(
                            ipAddress: serverIP,
                            targetFolder: targetFolder,
                            username: username,
                            password: password,
                            port: port,
                            onStatus: onStatus
                        )
                        cacheServer(networkInfo)
                        onStatus?(.connected(networkInfo))
                        return networkInfo
                    } catch {
                        logger.debug("Failed to connect to discovered server \(service.name): \(error.localizedDescription)")
                        continue
                    }
                }
                
                if services.isEmpty && retryCount < maxRetries {
                    retryCount += 1
                    logger.info("No services found, retrying Bonjour...")
                    try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1s before retry
                    continue
                }
                
                if services.isEmpty {
                    let error = ConnectionError.noHostsFound
                    onStatus?(.failure(error))
                    throw error
                } else {
                    let error = ConnectionError.authenticationFailed // Most likely reason if we found servers but couldn't connect
                    onStatus?(.failure(error))
                    throw error
                }
            } catch {
                if retryCount < maxRetries {
                    retryCount += 1
                    continue
                }
                logger.error("Server discovery failed: \(error.localizedDescription)")
                let finalError = mapToConnectionError(error)
                onStatus?(.failure(finalError))
                throw finalError
            }
        }
        
        throw ConnectionError.timeout
    }
}

// MARK: - Interactive Discovery
extension NetworkDiscovery {
    internal func discoverAvailableHosts(
        onStatus: (@Sendable (ConnectionStatus) -> Void)? = nil
    ) async throws -> [DiscoveredHost] {
        var hosts: [String: DiscoveredHost] = [:]
        
        // 1. Subnet Scan
        try Task.checkCancellation()
        onStatus?(.discovery(.subnetScan(progress: 0.0)))
        let ips = try await fastSubnetScan(onProgress: { progress in
            onStatus?(.discovery(.subnetScan(progress: progress)))
        })
        for ip in ips {
            hosts[ip] = DiscoveredHost(id: ip, name: nil)
        }
        
        // 2. Bonjour
        try Task.checkCancellation()
        onStatus?(.discovery(.bonjourSearch))
        let services = try await discoverSMBServers(timeout: 5.0)
        for service in services {
            try Task.checkCancellation()
            onStatus?(.discovery(.resolving(service.name)))
            if let ip = try? await resolveService(service) {
                hosts[ip] = DiscoveredHost(id: ip, name: service.name)
            }
        }
        
        if hosts.isEmpty {
            throw ConnectionError.noHostsFound
        }
        
        return Array(hosts.values).sorted { 
            ($0.name ?? $0.id).lowercased() < ($1.name ?? $1.id).lowercased()
        }
    }

    internal func listAvailableShares(
        ipAddress: String,
        username: String,
        password: String,
        port: Int? = nil
    ) async throws -> [String] {
        var components = URLComponents()
        components.scheme = "smb"
        components.host = ipAddress
        if let port = port { components.port = port }
        guard let serverURL = components.url else { throw ConnectionError.hostNotFound(ipAddress) }
        
        guard let client = SMB2Manager(
            url: serverURL,
            credential: URLCredential(user: username, password: password, persistence: .forSession)
        ) else {
            throw ConnectionError.unknown("Failed to create SMB client")
        }
        
        do {
            try await client.connectShare(name: "IPC$")
            let shares = try await client.listShares()
            try? await client.disconnectShare()
            return shares.map { $0.name }.filter { !$0.hasSuffix("$") }.sorted()
        } catch {
            throw mapToConnectionError(error)
        }
    }
}

// MARK: - Fast Subnet Scanning
extension NetworkDiscovery {
    private func fastSubnetScan(startIP: Int = 1, batchSize: Int = 25, onProgress: (@Sendable (Double) -> Void)? = nil) async throws -> [String] {
        let currentIP = await getCurrentDeviceIP() ?? "192.168.1.1"
        let subnet = currentIP.split(separator: ".").dropLast().joined(separator: ".")
        
        let totalIPs = 254
        var currentStart = startIP
        var foundIPs: [String] = []
        
        while currentStart <= totalIPs {
            try Task.checkCancellation()
            let endIP = min(currentStart + batchSize - 1, totalIPs)
            onProgress?(Double(currentStart) / Double(totalIPs))
            
            let batchResults = try await withThrowingTaskGroup(of: String?.self, body: { group -> [String] in
                for i in currentStart...endIP {
                    group.addTask {
                        let ip = "\(subnet).\(i)"
                        if try await self.quickPortCheck(ip: ip, port: 445, timeout: 0.1) {
                            return ip
                        }
                        return nil
                    }
                }
                
                var results: [String] = []
                for try await result in group {
                    if let ip = result {
                        results.append(ip)
                    }
                }
                return results
            })
            
            foundIPs.append(contentsOf: batchResults)
            currentStart += batchSize
        }
        onProgress?(1.0)
        return foundIPs
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
    private func mapToConnectionError(_ error: Error) -> ConnectionError {
        if error is CancellationError {
            return .cancelled
        }
        if let connError = error as? ConnectionError {
            return connError
        }
        
        let nsError = error as NSError
        
        // Handle AMSMB2 / libsmb2 errors
        // POSIX EPERM (1) or EACCES (13) often mean auth failure or permission denied
        if nsError.domain == NSPOSIXErrorDomain {
            if nsError.code == 1 || nsError.code == 13 { // EPERM, EACCES
                return .authenticationFailed
            }
            if nsError.code == 60 { // ETIMEDOUT
                return .timeout
            }
        }
        
        if nsError.localizedDescription.localizedCaseInsensitiveContains("timed out") {
            return .timeout
        }
        
        return .unknown(error.localizedDescription)
    }

    private func attemptConnection(
        ipAddress: String,
        targetFolder: String,
        username: String,
        password: String,
        port: Int? = nil,
        onStatus: (@Sendable (ConnectionStatus) -> Void)? = nil
    ) async throws -> NetworkInfo {
        logger.info("Attempting SMB connection to Host/IP: \(ipAddress), Target Folder: '\(targetFolder)'")
        onStatus?(.connecting(ipAddress))

        var components = URLComponents()
        components.scheme = "smb"
        components.host = ipAddress
        if let port = port {
            components.port = port
            logger.debug("Using explicit port: \(port)")
        }
        guard let serverURL = components.url else {
            logger.critical("Failed to create URL for host: \(ipAddress)")
            throw ConnectionError.hostNotFound(ipAddress)
        }

        logger.debug("Connecting to URL: \(serverURL.absoluteString)")

        guard let client = SMB2Manager(
            url: serverURL,
            credential: URLCredential(user: username, password: password, persistence: .forSession)
        ) else {
            logger.error("Failed to create SMB2Manager instance for \(serverURL.absoluteString)")
            throw ConnectionError.unknown("Failed to create SMB client instance.")
        }

        let normalizedTarget = targetFolder
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/\\"))
        guard !normalizedTarget.isEmpty else {
            logger.error("Target folder name cannot be empty or just slashes.")
            throw ConnectionError.folderNotFound("Target folder name is invalid.")
        }

        var enumeratedShares: [(name: String, comment: String)] = []
        var shareEnumerationError: Error?
        do {
            logger.debug("Connecting to IPC$ on \(ipAddress) to list shares...")
            onStatus?(.authenticating)
            try await client.connectShare(name: "IPC$")
            enumeratedShares = try await client.listShares()
            logger.info("Found shares on \(ipAddress): \(enumeratedShares.map { $0.name })")
        } catch {
            shareEnumerationError = error
            logger.notice("Share enumeration failed on \(ipAddress): \(error.localizedDescription)")
        }
        try? await client.disconnectShare()

        var candidateKeys = Set<String>()
        var candidates: [(share: String, directory: String?)] = []
        func addCandidate(share: String, directory: String?) {
            let trimmedShare = share.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedShare.isEmpty else { return }
            let trimmedDirectory = directory?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/\\"))
            let key = trimmedShare.lowercased() + "|" + (trimmedDirectory?.lowercased() ?? "")
            if candidateKeys.insert(key).inserted {
                candidates.append((trimmedShare, trimmedDirectory?.isEmpty == true ? nil : trimmedDirectory))
            }
        }

        if !enumeratedShares.isEmpty {
            if let exactMatch = enumeratedShares.first(where: { $0.name.compare(normalizedTarget, options: String.CompareOptions.caseInsensitive) == .orderedSame }) {
                addCandidate(share: exactMatch.name, directory: nil)
            }
            if !normalizedTarget.isEmpty {
                for share in enumeratedShares {
                    addCandidate(share: share.name, directory: normalizedTarget)
                }
            } else {
                for share in enumeratedShares {
                    addCandidate(share: share.name, directory: nil)
                }
            }
        }

        // FIX: rename to pathComponents to avoid redeclaration with URLComponents
        let pathComponents = normalizedTarget.split(separator: "/", omittingEmptySubsequences: true)
        if let shareGuess = pathComponents.first {
            let remainder = pathComponents.dropFirst().joined(separator: "/")
            addCandidate(share: String(shareGuess), directory: remainder.isEmpty ? nil : remainder)
        }
        addCandidate(share: normalizedTarget, directory: nil)

        var lastError: Error?
        for candidate in candidates {
            do {
                onStatus?(.connecting("Share: \(candidate.share)"))
                try await client.connectShare(name: candidate.share)
                logger.debug("Connected to share '\(candidate.share)' on \(ipAddress)")

                if let directory = candidate.directory, !directory.isEmpty {
                    do {
                        try await ensureDirectoryExists(directory, in: client, shareName: candidate.share)
                        try await client.disconnectShare()
                        logger.info("Validated share '\(candidate.share)' with directory '\(directory)'.")
                        let info = NetworkInfo(serverIP: ipAddress, shareName: candidate.share, targetDirectory: directory)
                        onStatus?(.connected(info))
                        return info
                    } catch {
                        lastError = error
                        logger.debug("Directory validation failed for share '\(candidate.share)': \(error.localizedDescription)")
                        try? await client.disconnectShare()
                    }
                } else {
                    try await client.disconnectShare()
                    logger.info("Validated share '\(candidate.share)' (no subdirectory required).")
                    let info = NetworkInfo(serverIP: ipAddress, shareName: candidate.share, targetDirectory: nil)
                    onStatus?(.connected(info) )
                    return info
                }
            } catch {
                lastError = error
                logger.debug("Failed to connect to share '\(candidate.share)': \(error.localizedDescription)")
                try? await client.disconnectShare()
            }
        }

        if let shareEnumerationError = shareEnumerationError, enumeratedShares.isEmpty {
            logger.error("Share enumeration failed on \(ipAddress): \(shareEnumerationError.localizedDescription)")
            throw mapToConnectionError(shareEnumerationError)
        }

        if let lastError = lastError {
            logger.error("Failed to validate target '\(normalizedTarget)' on \(ipAddress): \(lastError.localizedDescription)")
            throw mapToConnectionError(lastError)
        }

        logger.error("Target folder '\(normalizedTarget)' not found as an accessible directory within any share on server \(ipAddress)")
        throw ConnectionError.folderNotFound(normalizedTarget)
    }

    private func ensureDirectoryExists(_ path: String, in client: SMB2Manager, shareName: String) async throws {
        do {
            _ = try await client.contentsOfDirectory(atPath: path)
        } catch let nsError as NSError {
            if nsError.domain == NSPOSIXErrorDomain {
                switch nsError.code {
                case Int(ENOENT):
                    throw ConnectionError.folderNotFound(path)
                case Int(EACCES):
                    throw ConnectionError.authenticationFailed
                default:
                    throw nsError
                }
            }
            if nsError.domain == "AMSMB2ErrorDomain" {
                switch nsError.code {
                case 0x00000002, 0xC0000034:
                    throw ConnectionError.folderNotFound(path)
                case 0xC0000103:
                    throw ConnectionError.folderNotFound("Path exists but is not a directory")
                default:
                    throw nsError
                }
            }
            throw nsError
        }
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

struct DiscoveryResultsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appData: AppData
    
    let username: String
    let password: String
    let port: Int?
    let onSelect: (NetworkInfo) -> Void
    
    @State private var discoveredHosts: [DiscoveredHost] = []
    @State private var discoveredShares: [String] = []
    @State private var selectedHost: DiscoveredHost? = nil
    @State private var isLoading = false
    @State private var statusMessage = "Initializing..."
    @State private var errorMessage: String? = nil
    @State private var discoveryTask: Task<Void, Never>? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                if let error = errorMessage {
                    VStack(spacing: 15) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            startHostDiscovery()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if isLoading && discoveredHosts.isEmpty {
                    VStack(spacing: 20) {
                        ProgressView()
                            .controlSize(.large)
                        Text(statusMessage)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        if selectedHost == nil {
                            Section("Available Servers") {
                                if discoveredHosts.isEmpty && !isLoading {
                                    Text("No servers found. Make sure you are on the same Wi-Fi.")
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(discoveredHosts) { host in
                                        Button {
                                            fetchShares(for: host)
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading) {
                                                    Text(host.name ?? "Unknown Server")
                                                        .font(.headline)
                                                    Text(host.id)
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                                if isLoading && selectedHost?.id == host.id {
                                                    ProgressView()
                                                } else {
                                                    Image(systemName: "chevron.right")
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            Section {
                                Button {
                                    selectedHost = nil
                                    discoveredShares = []
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.left")
                                        Text("Back to Servers")
                                    }
                                }
                                .foregroundColor(.blue)
                            }
                            
                            Section("Shares on \(selectedHost?.displayName ?? "")") {
                                if isLoading {
                                    HStack {
                                        ProgressView()
                                            .padding(.trailing, 10)
                                        Text("Listing shares...")
                                    }
                                } else if discoveredShares.isEmpty {
                                    Text("No accessible shares found. Check credentials or permissions.")
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(discoveredShares, id: \.self) { share in
                                        Button {
                                            selectShare(share)
                                        } label: {
                                            HStack {
                                                Text(share)
                                                Spacer()
                                                Image(systemName: "checkmark.circle")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(selectedHost == nil ? "Discovered Servers" : "Choose Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        discoveryTask?.cancel()
                        dismiss()
                    }
                }
            }
            .onAppear {
                startHostDiscovery()
            }
            .onDisappear {
                discoveryTask?.cancel()
            }
        }
    }
    
    private func startHostDiscovery() {
        errorMessage = nil
        discoveredHosts = []
        isLoading = true
        
        discoveryTask?.cancel()
        discoveryTask = Task {
            do {
                let hosts = try await NetworkDiscovery.shared.discoverAvailableHosts(onStatus: { status in
                    Task { @MainActor in
                        updateStatus(status)
                    }
                })
                
                if !Task.isCancelled {
                    await MainActor.run {
                        self.discoveredHosts = hosts
                        self.isLoading = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    private func updateStatus(_ status: ConnectionStatus) {
        switch status {
        case .discovery(let state):
            switch state {
            case .subnetScan(let progress):
                statusMessage = "Scanning network (\(Int(progress * 100))%)..."
            case .bonjourSearch:
                statusMessage = "Searching for servers..."
            case .resolving(let name):
                statusMessage = "Identifying \(name)..."
            }
        default:
            break
        }
    }
    
    private func fetchShares(for host: DiscoveredHost) {
        selectedHost = host
        isLoading = true
        discoveredShares = []
        errorMessage = nil
        
        Task {
            do {
                let shares = try await NetworkDiscovery.shared.listAvailableShares(
                    ipAddress: host.id,
                    username: username,
                    password: password,
                    port: port
                )
                
                if !Task.isCancelled {
                    await MainActor.run {
                        self.discoveredShares = shares
                        self.isLoading = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.errorMessage = "Failed to list shares: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    private func selectShare(_ share: String) {
        guard let host = selectedHost else { return }
        let info = NetworkInfo(serverIP: host.id, shareName: share, targetDirectory: nil)
        onSelect(info)
        dismiss()
    }
}

#Preview {
    DiscoveryResultsView(username: "", password: "", port: nil, onSelect: { _ in })
        .environmentObject(AppData())
}

