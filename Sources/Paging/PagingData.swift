//
//  PagingData.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

import Foundation
import Combine

public class PagingData<T: Any> {
    internal let currentValueSubject: CurrentValueSubject<PageEvent<T>, Never>
    
    internal let receiver: UiReceiver
    
    static func empty<T: Any>() -> PagingData<T> {
        return PagingData<T>(CurrentValueSubject<PageEvent<T>, Never>(PageEvent<T>.StaticList(data: [])), NoopReceiver())
    }
    
    init(_ currentValueSubject: CurrentValueSubject<PageEvent<T>, Never>, _ uiReceiver: UiReceiver) {
        self.currentValueSubject = currentValueSubject
        self.receiver = uiReceiver
    }
    
    class NoopReceiver: UiReceiver {
        func accessHint(viewportHint: ViewportHint) {}
        
        func retry() {}
        
        func refresh() {}
    }
}
