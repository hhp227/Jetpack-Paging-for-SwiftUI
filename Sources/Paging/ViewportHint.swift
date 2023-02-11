//
//  ViewportHint.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

class ViewportHint: Equatable {
    let presentedItemsBefore: Int
    
    let presentedItemsAfter: Int
    
    let originalPageOffsetFirst: Int
    
    let originalPageOffsetLast: Int
    
    func presentedItemsBeyondAnchor(_ loadType: LoadType) -> Int {
        switch loadType {
        case .REFRESH:
            fatalError("Cannot get presentedItems for loadType: REFRESH")
        case .PREPEND:
            return presentedItemsBefore
        case .APPEND:
            return presentedItemsAfter
        }
    }
    
    static func == (lhs: ViewportHint, rhs: ViewportHint) -> Bool {
        return lhs.presentedItemsBefore == rhs.presentedItemsBefore && lhs.presentedItemsAfter == rhs.presentedItemsAfter && lhs.originalPageOffsetFirst == rhs.originalPageOffsetFirst && lhs.originalPageOffsetLast == rhs.originalPageOffsetLast
    }
    
    final class Initial: ViewportHint {
        override init(presentedItemsBefore: Int, presentedItemsAfter: Int, originalPageOffsetFirst: Int, originalPageOffsetLast: Int) {
            super.init(presentedItemsBefore: presentedItemsBefore, presentedItemsAfter: presentedItemsAfter, originalPageOffsetFirst: originalPageOffsetFirst, originalPageOffsetLast: originalPageOffsetLast)
        }
    }
    
    final class Access: ViewportHint {
        var pageOffset: Int
        
        var indexInPage: Int
        
        init(pageOffset: Int, indexInPage: Int, presentedItemsBefore: Int, presentedItemsAfter: Int, originalPageOffsetFirst: Int, originalPageOffsetLast: Int) {
            self.pageOffset = pageOffset
            self.indexInPage = indexInPage
            super.init(presentedItemsBefore: presentedItemsBefore, presentedItemsAfter: presentedItemsAfter, originalPageOffsetFirst: originalPageOffsetFirst, originalPageOffsetLast: originalPageOffsetLast)
        }
    }
    
    init(
        presentedItemsBefore: Int,
        presentedItemsAfter: Int,
        originalPageOffsetFirst: Int,
        originalPageOffsetLast: Int
    ) {
        self.presentedItemsBefore = presentedItemsBefore
        self.presentedItemsAfter = presentedItemsAfter
        self.originalPageOffsetFirst = originalPageOffsetFirst
        self.originalPageOffsetLast = originalPageOffsetLast
    }
}
