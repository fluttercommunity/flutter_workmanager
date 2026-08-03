// WorkmanagerPlugin+Progress.swift
//
// Progress updates are Android-only (WorkManager `setProgress`); there is no
// equivalent for BGTaskScheduler / NSBackgroundActivityScheduler, so the
// pigeon host methods are documented no-ops here.
import Foundation

#if os(iOS)
extension WorkmanagerPlugin {
    func reportProgress(progress: [String?: Any?]?, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func setProgressListener(enabled: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}
#elseif os(macOS)
extension WorkmanagerPlugin {
    func reportProgress(progress: [String?: Any?]?, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func setProgressListener(enabled: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}
#endif
