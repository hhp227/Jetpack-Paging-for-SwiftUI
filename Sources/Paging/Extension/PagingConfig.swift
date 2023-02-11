//
//  PagingConfig.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/26.
//

import Foundation

// 완료
public class PagingConfig {
    let pageSize: Int
    
    let prefetchDistance: Int
    
    let enablePlaceholders: Bool = true
    
    let initialLoadSize: Int
    
    let maxSize: Int = MAX_SIZE_UNBOUNDED
    
    let jumpThreshold: Int = Int.min
    
    static let MAX_SIZE_UNBOUNDED = Int.max
    
    internal static let DEFAULT_INITIAL_PAGE_MULTIPLIER = 3
    
    public init(pageSize: Int) {
        self.pageSize = pageSize
        self.prefetchDistance = self.pageSize
        self.initialLoadSize = self.pageSize * PagingConfig.DEFAULT_INITIAL_PAGE_MULTIPLIER
        
        if !enablePlaceholders && prefetchDistance == 0 {
            fatalError("Placeholders and prefetch are the only ways to trigger loading of more data in PagingData, so either placeholders must be enabled, or prefetch distance must be > 0")
        }
        if maxSize != PagingConfig.MAX_SIZE_UNBOUNDED && maxSize < pageSize + prefetchDistance * 2 {
            fatalError("jumpThreshold must be positive to enable jumps or COUNT_UNDEFINED to disable jumping.")
        }
        guard jumpThreshold == Int.min || jumpThreshold > 0 else {
            fatalError("jumpThreshold must be positive to enable jumps or COUNT_UNDEFINED to disable jumping.")
        }
    }
}
