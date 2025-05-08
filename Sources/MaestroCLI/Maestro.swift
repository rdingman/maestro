import ArgumentParser
import Foundation

@main
struct Maestro: AsyncParsableCommand {
    mutating func run() async throws {
        print("Running")

        let platform = Platform()
        print(platform)

        if let browserPlatform: Browser.Platform = getBrowserPlatform() {
            print(browserPlatform)
            print(Browser.chromeHeadlessShell.downloadUrl(for: browserPlatform, buildId: "137.0.7143.0").absoluteString)
        }
/*
 export const testChromeBuildId = '127.0.6533.72';
 export const testChromiumBuildId = '1083080';
 export const testFirefoxBuildId = 'stable_129.0';
 export const testChromeDriverBuildId = '127.0.6533.72';
 export const testChromeHeadlessShellBuildId = '127.0.6533.72';
 */
        print("Done")
    }

    func getBrowserPlatform() -> Browser.Platform? {
        let platform = Platform()

        switch (platform.sysname, platform.architecture) {
        case ("Darwin", "arm64"): return .macArm
        case ("Darwin", _): return .mac
        case ("linux", "arm64"): return .linuxArm
        case ("linux", _): return .linux
        default: return nil
        }
    }
}
