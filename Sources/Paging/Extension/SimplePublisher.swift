//
//  SimplePublisher.swift
//  
//
//  Created by 홍희표 on 2024/11/30.
//

import Foundation
import Combine

struct SimplePublisher<T>: Publisher {
    typealias Output = T
    
    typealias Failure = Never
    
    let callback: ((@escaping (T) -> Void) -> Void)
    
    func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, T == S.Input {
        let subscription = SimpleSubscription(subscriber: subscriber, callback: callback)
        subscriber.receive(subscription: subscription)
    }
    
    private class SimpleSubscription<S: Subscriber>: Subscription where S.Input == T, S.Failure == Never {
        var subscriber: S?
        var callback: ((@escaping (T) -> Void) -> Void)
        var demand: Subscribers.Demand = .none
        var isCancelled = false
        
        init(subscriber: S, callback: @escaping (@escaping (T) -> Void) -> Void) {
            self.subscriber = subscriber
            self.callback = callback
        }
        
        func request(_ demand: Subscribers.Demand) {
            self.demand += demand
            
            callback({ value in
                guard self.demand > 0, !self.isCancelled else { return }
                self.demand -= 1
                _ = self.subscriber?.receive(value)
            })
        }
        
        func cancel() {
            isCancelled = true
            subscriber = nil
        }
    }
}
