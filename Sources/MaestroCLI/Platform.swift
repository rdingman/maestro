//
//
//  Created by Ryan Dingman on 4/23/25.
//

import Foundation

// During install run the following to make sure that on macOS we tell gatekeeper that the download is ok
// xattr -cr 'chrome-headless-shell'
struct Platform {
    let sysname: String
    let nodename: String
    let release: String
    let version: String
    let architecture: String

    init() {
        func convertToString<T>(from value: inout T) -> String where T: ~Copyable {
            withUnsafePointer(to: &value) {
                $0.withMemoryRebound(to: CChar.self, capacity:  1) {
                    String(cString: $0)
                }
            }
        }

        var systemInfo = utsname()
        uname(&systemInfo)

        sysname = convertToString(from: &systemInfo.sysname)
        nodename = convertToString(from: &systemInfo.nodename)
        release = convertToString(from: &systemInfo.release)
        version = convertToString(from: &systemInfo.version)
        architecture = convertToString(from: &systemInfo.machine)
    }
}


enum Browser: String {
    case chrome = "chrome"
    case chromeHeadlessShell = "chrome-headless-shell"
    case chromium = "chromium"
    case firefox = "firefox"
    case chromeDriver = "chromedriver"

    // Platform names used to identify a OS platform x architecture combination in the way
    // that is relevant for the browser download.

    enum Platform: String {
        case linux = "linux"
        case linuxArm = "linux_arm"
        case mac = "mac"
        case macArm = "mac_arm"
        case win32 = "win32"
        case win64 = "win64"
    }

    // Enum describing a release channel for a browser.

    enum Tag: String {
        case canary = "canary"
        case nightly = "nightly"
        case beta = "beta"
        case dev = "dev"
        case devEdition = "devedition"
        case stable = "stable"
        case esr = "esr"
        case latest = "latest"
    }

    private var baseUrl: URL {
        switch self {
        case .chrome, .chromeHeadlessShell, .chromeDriver:
            return URL(string: "https://storage.googleapis.com/chrome-for-testing-public/")!

        case .chromium:
            return URL(string: "https://storage.googleapis.com/chromium-browser-snapshots/")!

        case .firefox:
            return URL(string: "https://archive.mozilla.org/pub/")!
        }
    }

    private func folder(for platform: Platform) -> String {
        switch self {
        case .chrome, .chromeHeadlessShell, .chromeDriver:
            return switch platform {
            case .linux, .linuxArm: "linux64"
            case .mac: "mac-x64"
            case .macArm: "mac-arm64"
            case .win32: "win32"
            case .win64: "win64"
            }

        case .chromium:
            return switch platform {
            case .linux: "Linux_x64"
            case .mac, .linuxArm: "Mac"
            case .macArm: "Mac_Arm"
            case .win32: "Win"
            case .win64: "Win_x64"
            }

        case .firefox:
            return ""
        }
    }

    private func downloadPath(for platform: Platform, buildId: String) -> String {
        var components = [String]()

        switch self {

        case .chrome:
            components = [buildId, folder(for: platform), "chrome-\(folder(for: platform)).zip"]

        case .chromeHeadlessShell:
            components = [buildId, folder(for: platform), "chrome-headless-shell-\(folder(for: platform)).zip"]

        case .chromeDriver:
            components = [buildId, folder(for: platform), "chromedriver-\(folder(for: platform)).zip"]

        case .chromium:
            /*   switch (platform) {
             case BrowserPlatform.LINUX_ARM:
             case BrowserPlatform.LINUX:
               return 'chrome-linux';
             case BrowserPlatform.MAC_ARM:
             case BrowserPlatform.MAC:
               return 'chrome-mac';
             case BrowserPlatform.WIN32:
             case BrowserPlatform.WIN64:
               // Windows archive name changed at r591479.
               return parseInt(buildId, 10) > 591479 ? 'chrome-win' : 'chrome-win32';
           }
*/
            let archive = switch platform {
            case .linux, .linuxArm: "chrome-linux"
            case .mac, .macArm: "chrome-mac"
            // Windows archive name changed at r591479.
            case .win32, .win64: Int(buildId).map { $0 > 591479 ? "chrome-win" : "chrome-win32" } ?? "chrome-win32"
            }

            components = [folder(for: platform), buildId, "\(archive).zip"]

        case .firefox:
            let (channel, resolvedBuildId) = parseFirefoxBuildId(buildId)

            let platformName = switch platform {
            case .linux: "linux-x86_64"
            case .linuxArm: "linux-aarch64"
            case .mac, .macArm: "mac"
            case .win32, .win64: "\(platform.rawValue)"
            }

            let format: String
            let regex = /^(0|[1-9]\d*)\./
            //let regex = /^(?'major'\d+)\.(?'minor'\d+)(?:\.(?'patch'\d+))?(?:-(?'preRelease'(?:(?'preReleaseId'[0-9A-Za-z-]+)\.?)+))?(?:\+(?'build'(?:(?'buildId'[0-9A-Za-z-]+)\.?)+))?$/
            if let result = try? regex.firstMatch(in: resolvedBuildId), !result.0.isEmpty {
                format = Int(result.1).map { $0 > 135 ? "xz" : "bz2" } ?? "xz"
            } else {
                format = "xz"
            }

            let archive = switch platform {
            case .linux, .linuxArm: "firefox-${buildId}.tar.\(format)"
            case .mac, .macArm: "Firefox \(resolvedBuildId).dmg";
            case .win32, .win64: "Firefox Setup \(resolvedBuildId).exe"
            }

            components = [
              resolvedBuildId,
              platformName,
              "en-US",
              archive
            ]
        }

        return components.joined(separator: "/")
    }

    private func parseFirefoxBuildId(_ buildId: String) -> (FirefoxChannel, String) {
        for channel in FirefoxChannel.allCases {
            if buildId.starts(with: "\(channel.rawValue)_") {
                let index = buildId.index(buildId.startIndex, offsetBy: channel.rawValue.count + 1)
                return (channel, String(buildId.suffix(from: index)))
            }
        }

        return (.nightly, buildId)
    }

    func downloadUrl(for platform: Platform, buildId: String) -> URL {
        switch self {
        case .chrome, .chromeHeadlessShell, .chromeDriver, .chromium:
            return URL(string: downloadPath(for: platform, buildId: buildId), relativeTo: baseUrl)!

        case .firefox:
            let (channel, _) = parseFirefoxBuildId(buildId)
            let baseUrl: URL

            switch channel {

            case .stable, .esr, .beta, .devEdition:
                baseUrl = URL(string: "https://archive.mozilla.org/pub/firefox/releases/")!
            case .nightly:
                baseUrl = URL(string: "https://archive.mozilla.org/pub/firefox/nightly/latest-mozilla-central/")!
            }

            return URL(string: downloadPath(for: platform, buildId: buildId), relativeTo: baseUrl)!
        }
    }

    private enum FirefoxChannel: String, CaseIterable {
        case stable = "stable"
        case esr = "esr"
        case devEdition = "devedition"
        case beta = "beta"
        case nightly = "nightly"
    }
}
