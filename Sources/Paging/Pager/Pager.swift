//
//  Pager.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

import Combine

public class Pager<Key: Equatable, Value: Any> {
    public let publisher: AnyPublisher<PagingData<Value>, Never>
    
    public init(_ config: PagingConfig, _ initialKey: Key? = nil, _ pagingSourceFactory: @escaping () -> PagingSource<Key, Value>) {
        self.publisher = PageFetcher(pagingSourceFactory, initialKey, config).publisher
    }
}
