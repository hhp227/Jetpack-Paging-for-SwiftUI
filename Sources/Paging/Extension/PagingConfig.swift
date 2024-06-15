//
//  PagingConfig.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/26.
//

import Foundation

public class PagingConfig {
    public let pageSize: Int
    
    public let prefetchDistance: Int
    
    public let enablePlaceholders: Bool
    
    public let initialLoadSize: Int
    
    public let maxSize: Int = MAX_SIZE_UNBOUNDED
    
    public let jumpThreshold: Int = Int.min
    
    public static let MAX_SIZE_UNBOUNDED = Int.max
    
    internal static let DEFAULT_INITIAL_PAGE_MULTIPLIER = 3
    
    public init(
        pageSize: Int,
        prefetchDistance: Int? = nil,
        enablePlaceholders: Bool = true,
        initialLoadSize: Int? = nil,
        maxSize: Int = PagingConfig.MAX_SIZE_UNBOUNDED,
        jumpThreshold: Int = Int.min
    ) {
        self.pageSize = pageSize
        self.prefetchDistance = prefetchDistance ?? pageSize
        self.enablePlaceholders = enablePlaceholders
        self.initialLoadSize = initialLoadSize ?? self.pageSize * PagingConfig.DEFAULT_INITIAL_PAGE_MULTIPLIER
        
        if !enablePlaceholders && prefetchDistance == 0 {
            fatalError("Placeholders and prefetch are the only ways to trigger loading of more data in PagingData, so either placeholders must be enabled, or prefetch distance must be > 0")
        }
        if maxSize != PagingConfig.MAX_SIZE_UNBOUNDED && maxSize < pageSize + self.prefetchDistance * 2 {
            fatalError("jumpThreshold must be positive to enable jumps or COUNT_UNDEFINED to disable jumping.")
        }
        guard jumpThreshold == Int.min || jumpThreshold > 0 else {
            fatalError("jumpThreshold must be positive to enable jumps or COUNT_UNDEFINED to disable jumping.")
        }
    }
}
