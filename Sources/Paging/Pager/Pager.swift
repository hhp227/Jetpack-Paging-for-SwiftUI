//
//  Pager.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

import Combine

public class Pager<Key: Equatable, Value: Any> {
    public let publisher: AnyPublisher<PagingData<Value>, Never>
    
    public init(
        config: PagingConfig,
        initialKey: Key? = nil,
        remoteMediator: RemoteMediator<Key, Value>?,
        pagingSourceFactory: @escaping () -> PagingSource<Key, Value>
    ) {
        self.publisher = PageFetcher(pagingSourceFactory, initialKey, config).publisher
    }
    
    public convenience init(
        config: PagingConfig,
        initialKey: Key? = nil,
        pagingSourceFactory: @escaping () -> PagingSource<Key, Value>
    ) {
        self.init(config: config, initialKey: initialKey, remoteMediator: nil, pagingSourceFactory: pagingSourceFactory)
    }
}
