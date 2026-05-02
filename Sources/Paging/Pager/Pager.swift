//
//  Pager.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

import Combine

public class Pager<Key: Equatable, Value: Any> {
    let publisher: AnyPublisher<PagingData<Value>, Never>
    
    init(
        _ config: PagingConfig,
        _ initialKey: Key? = nil,
        _ remoteMediator: RemoteMediator<Key, Value>?,
        _ pagingSourceFactory: @escaping () -> PagingSource<Key, Value>
    ) {
        self.publisher = PageFetcher(
            pagingSourceFactory,
            initialKey,
            config,
            remoteMediator
        ).publisher
    }

    convenience init(
        _ config: PagingConfig,
        _ initialKey: Key? = nil,
        _ pagingSourceFactory: @escaping () -> PagingSource<Key, Value>
    ) {
        self.init(config, initialKey, nil, pagingSourceFactory)
    }
}
