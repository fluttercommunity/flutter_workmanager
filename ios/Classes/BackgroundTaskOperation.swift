//
//  BackgroundTaskOperation.swift
//  workmanager
//
//  Created by Sebastian Roth on 10/06/2021.
//

import Foundation

class BackgroundTaskOperation: Operation {

    private let identifier: String
    private let flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?

    init(_ identifier: String, flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?) {
        self.identifier = identifier
        self.flutterPluginRegistrantCallback = flutterPluginRegistrantCallback
    }

    override func main() {
        let semaphore = DispatchSemaphore(value: 0)

        DispatchQueue.main.async {
            let worker = BackgroundWorker(mode: .backgroundTask(identifier: self.identifier),
                                          flutterPluginRegistrantCallback: self.flutterPluginRegistrantCallback)

            worker.performBackgroundRequest { _ in
                semaphore.signal()
            }
        }

        semaphore.wait()
    }
}
