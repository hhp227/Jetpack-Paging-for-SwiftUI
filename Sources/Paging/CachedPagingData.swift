//
//  CachedPagingData.swift
//  Application
//
//  Created by hhp227 on 6/11/24.
//

import Foundation
import Combine

private class MulticastedPagingData<T: Any> {
    let parent: PagingData<T>

    let tracker: ActivePublisherTracker?

    private lazy var accumulated = CachedPageEventPublisher(
        src: parent.publisher.handleEvents(
            receiveSubscription: { _ in self.tracker?.onStart(publisherType: .pageEventPublisher) },
            receiveCompletion: { _ in self.tracker?.onComplete(publisherType: .pageEventPublisher) }
        ).eraseToAnyPublisher()
    )

    func asPagingData() -> PagingData<T> {
        return PagingData(accumulated.downstreamPublisher, parent.receiver)
    }
    
    func close() {
        accumulated.close()
    }

    init(parent: PagingData<T>, tracker: ActivePublisherTracker? = nil) {
        self.parent = parent
        self.tracker = tracker
    }
}

extension Publisher where Failure == Never {
    func cachedIn<T: Any>() -> AnyPublisher<PagingData<T>, Never> {
        return cachedIn(tracker: nil)
    }
    
    func cachedIn<T: Any>(tracker: ActivePublisherTracker?) -> AnyPublisher<PagingData<T>, Never> {
        return self.map { MulticastedPagingData(parent: $0 as! PagingData<T>) }
            .runningReduce { (prev: MulticastedPagingData, next: MulticastedPagingData) in
                prev.close()
                return next
            }
            .map { $0.asPagingData() }
            .handleEvents(
                receiveSubscription: { _ in tracker?.onStart(publisherType: .pagedDataPublisher) },
                receiveCompletion: { _ in tracker?.onComplete(publisherType: .pagedDataPublisher) }
            )
            .share()
            .eraseToAnyPublisher()
    }
}

internal protocol ActivePublisherTracker {
    func onStart(publisherType: PublisherType)
    func onComplete(publisherType: PublisherType)
}

enum PublisherType {
    case pagedDataPublisher
    case pageEventPublisher
}
