import Foundation
import OSLog
import Network

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NetworkDiscovery")

@MainActor
final class NetworkDiscovery: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    static let shared = NetworkDiscovery()
    
    private let browser: NetServiceBrowser
    private var discoveredServices: [NetService] = []

    private override init() {
        self.browser = NetServiceBrowser()
        super.init()
        self.browser.delegate = self
    }

    func startDiscovery() {
        logger.info("Starting Bonjour discovery for _lanimageuploader._tcp")
        discoveredServices.removeAll()
        browser.searchForServices(ofType: "_lanimageuploader._tcp.", inDomain: "local.")
    }

    func stopDiscovery() {
        logger.info("Stopping Bonjour discovery.")
        browser.stop()
    }

    // MARK: - NetServiceBrowserDelegate
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        logger.info("Found service: \(service.name)")
        discoveredServices.append(service)
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        logger.info("Service removed: \(service.name)")
        discoveredServices.removeAll { $0 == service }
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        logger.info("Bonjour search stopped.")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        logger.error("Bonjour search failed: \(errorDict.description)")
    }
    
    // MARK: - NetServiceDelegate

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let host = sender.hostName, let port = sender.port else {
            logger.warning("Could not resolve address for service \(sender.name)")
            return
        }
        logger.info("Successfully resolved service \(sender.name) to \(host):\(port)")
        // Here, we could potentially update the app's state with the discovered server details
        // For now, we just log it.
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        logger.error("Failed to resolve service \(sender.name): \(errorDict.description)")
    }
}
