//
//  PagingState.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

public class PagingState<Key : Any, Value : Any> {
    let pages: [PagingSource<Key, Value>.LoadResult<Key, Value>.Page<Key, Value>]
    
    public let anchorPosition: Int?
    
    public let config: PagingConfig
    
    private let leadingPlaceholderCount: Int
    
    func closesItemToPosition(_ anchorPosition: Int) -> Value? {
        if pages.allSatisfy({ $0.data.isEmpty }) {
            return nil
        }
        return anchorPositionToPagedIndices(anchorPosition) { pageIndex, index in
            let firstNonEmptyPage = pages.first { !$0.data.isEmpty }
            let lastNonEmptyPage = pages.last { !$0.data.isEmpty }
            
            if index < 0 {
                return firstNonEmptyPage?.data.first
            } else if pageIndex == pages.endIndex - 1 && index > (pages.last?.data.endIndex)! - 1 {
                return lastNonEmptyPage?.data.last
            } else {
                return pages[pageIndex].data[index]
            }
        }
    }
    
    public func closestPageToPosition(_ anchorPosition: Int) -> PagingSource<Key, Value>.LoadResult<Key, Value>.Page<Key, Value>? {
        if pages.allSatisfy({ $0.data.isEmpty }) {
            return nil
        }
        return anchorPositionToPagedIndices(anchorPosition) { pageIndex, index in
            if index < 0 {
                return pages.first
            } else {
                return pages[pageIndex]
            }
        }
    }
    
    func isEmpty() -> Bool { pages.allSatisfy { $0.data.isEmpty } }
    
    func firstItemOrNil() -> Value? {
        return pages.first { !$0.data.isEmpty }?.data.first
    }
    
    func lastItemOrNil() -> Value? {
        return pages.last { !$0.data.isEmpty }?.data.last
    }
    
    @inline(__always) private func anchorPositionToPagedIndices<T>(
        _ anchorPosition: Int,
        _ block: (Int, Int) -> T
    ) -> T {
        var pageIndex = 0
        var index = anchorPosition - leadingPlaceholderCount
        
        while pageIndex < pages.endIndex - 1 && index > pages[pageIndex].data.endIndex - 1 {
            index -= pages[pageIndex].data.count
            pageIndex += 1
        }
        return block(pageIndex, index)
    }
    
    init(
        pages: [PagingSource<Key, Value>.LoadResult<Key, Value>.Page<Key, Value>],
        anchorPosition: Int?,
        config: PagingConfig,
        leadingPlaceholderCount: Int
    ) {
        self.pages = pages
        self.anchorPosition = anchorPosition
        self.config = config
        self.leadingPlaceholderCount = leadingPlaceholderCount
    }
}
