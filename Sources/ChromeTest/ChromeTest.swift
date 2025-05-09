
import ArgumentParser
import Foundation
import Maestro

@main
struct ChromeTest: AsyncParsableCommand {
    mutating func run() async throws {
        print("Running")

        let browser = try await Browser()

        let page = try await browser.newPage()
//        try await Task.sleep(for: .seconds(5))
        try await page.navigation(to: URL(string: "https://www.apple.com/")!)

        try await page.reload()
        try await Task.sleep(for: .seconds(5))
        let data = try await page.printToPDF()

        try data.write(to: URL(fileURLWithPath: "/tmp/apple.pdf"), options: [.atomicWrite])
        try await Task.sleep(for: .seconds(5))


        // We get the URL from calling curl http://localhost:63870/json/version
        // Launch with ./chrome-headless-shell --headless  --remote-debugging-port=2112

//        let targetId: String
//        let command = Browser.Target.CreateTargetCommand(url: URL(string: "https://www.apple.com/")!)
//        do {
//            let response = try await browser.sendCommand(command)
//            print("Result for create target: \(response)")
//            targetId = response.targetId
//        } catch {
//            print("***** Error: \(error)")
//            fatalError()
//        }
//
//        let attachCommand = Browser.Target.AttachToTargetCommand(targetId: targetId)
//        do {
//            let response = try await browser.sendCommand(attachCommand)
//            print("Result for attach to target: \(response)")
//        } catch {
//            print("***** Error: \(error)")
//        }
//
//        let printCommand = Browser.Page.PrintToPDFCommand()
//        do {
//            let response = try await browser.sendCommand(printCommand)
//            print("Result for print to PDF: \(response)")
//        } catch {
//            print("***** Error: \(error)")
//        }

        try await Task.sleep(for: .seconds(5))
        try await browser.close()
        try await Task.sleep(for: .seconds(5))
    }
}
