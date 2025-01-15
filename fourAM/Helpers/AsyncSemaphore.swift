//
//  AsyncSemaphore.swift
//  fourAM
//
//  Created by Jonas on 2025-01-15.
//

actor AsyncSemaphore {
    private let limit: Int
    private var currentCount: Int = 0
    private var waitingContinuations: [CheckedContinuation<Void, Never>] = []
    
    init(limit: Int) {
        self.limit = limit
    }
    
    func wait() async {
        if currentCount < limit {
            currentCount += 1
            return
        }
        
        await withCheckedContinuation { continuation in
            waitingContinuations.append(continuation)
        }
    }
    
    func signal() {
        if let continuation = waitingContinuations.first {
            waitingContinuations.removeFirst()
            continuation.resume()
        } else {
            currentCount -= 1
        }
    }
}
