//
//  PagingData.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

import Foundation
import Combine

public class PagingData<T: Any> {
    internal let publisher: AnyPublisher<PageEvent<T>, Never>

    internal let receiver: UiReceiver
    
    public static func empty() -> PagingData<T> {
        return PagingData<T>(CurrentValueSubject<PageEvent<T>, Never>(PageEvent<T>.StaticList(data: [])).eraseToAnyPublisher(), NoopReceiver())
    }
    
    init(_ publisher: AnyPublisher<PageEvent<T>, Never>, _ uiReceiver: UiReceiver) {
        self.publisher = publisher
        self.receiver = uiReceiver
    }
    
    class NoopReceiver: UiReceiver {
        func accessHint(viewportHint: ViewportHint) {}
        
        func retry() {}
        
        func refresh() {}
    }
}

