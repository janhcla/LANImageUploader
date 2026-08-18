enum AppBuildChannel: String {
    case production
    case testFlight
}

enum BuildDistributionChannel {
    static let current: AppBuildChannel = .production
}

print(BuildDistributionChannel.current.rawValue)
