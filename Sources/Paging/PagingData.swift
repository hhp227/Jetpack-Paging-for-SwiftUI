//
//  PagingData.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

import Foundation
import Combine

class PagingData<T: Any> {
    internal let publisher: AnyPublisher<PageEvent<T>, Never>

    internal let receiver: UiReceiver
    
    internal let hintReceiver: HintReceiver
    
    internal var cancellable: AnyCancellable? = nil
    
    static func empty<T: Any>() -> PagingData<T> {
        return PagingData<T>(CurrentValueSubject<PageEvent<T>, Never>(PageEvent<T>.StaticList(data: [])).eraseToAnyPublisher(), NoopReceiver(), NoopHintReceiver())
    }
    
    init(_ publisher: AnyPublisher<PageEvent<T>, Never>, _ uiReceiver: UiReceiver, _ hintReceiver: HintReceiver) {
        self.publisher = publisher
        self.receiver = uiReceiver
        self.hintReceiver = hintReceiver
    }
    
    deinit {
        cancellable?.cancel()
        cancellable = nil
    }
    
    class NoopReceiver: UiReceiver {
        func retry() {
        }
        
        func refresh() {
        }
    }
    
    class NoopHintReceiver: HintReceiver {
        func accessHint(viewportHint: ViewportHint) {
        }
    }
}
