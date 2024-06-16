//
//  PagingDataTransforms.swift
//  Paging
//
//  Created by 홍희표 on 2024/06/09.
//

import Foundation
import Combine

extension PagingData {
    public func transform<R: Any>(_ transform: @escaping (PageEvent<T>) -> PageEvent<R>) -> PagingData<T> {
        return PagingData(publisher.map { transform($0) }.upstream, receiver)
    }
    
    public func filter(_ predicate: @escaping (T) -> Bool) -> PagingData<T> {
        return transform { $0.filter(predicate) }
    }
}
