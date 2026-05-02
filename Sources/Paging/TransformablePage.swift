//
//  TransformablePage.swift
//  Paging
//
//  Created by 홍희표 on 2023/01/04.
//

import Foundation

struct TransformablePage<T: Any> {
    let originalPageOffsets: [Int]
    
    let data: [T]
    
    let hintOriginalPageOffset: Int
    
    let hintOriginalIndices: [Int]?
    
    func viewportHintFor(
        _ index: Int,
        _ presentedItemsBefore: Int,
        _ presentedItemsAfter: Int,
        _ originalPageOffsetFirst: Int,
        _ originalPageOffsetLast: Int
    ) -> ViewportHint.Access {
        ViewportHint.Access(
            pageOffset: hintOriginalPageOffset,
            indexInPage: hintOriginalIndices?.indices.contains(index) == true ? hintOriginalIndices![index] : index,
            presentedItemsBefore: presentedItemsBefore,
            presentedItemsAfter: presentedItemsAfter,
            originalPageOffsetFirst: originalPageOffsetFirst,
            originalPageOffsetLast: originalPageOffsetLast
        )
    }
    
    init(originalPageOffset: Int, data: [T]) {
        self.init(originalPageOffsets: [originalPageOffset], data: data, hintOriginalPageOffset: originalPageOffset, hintOriginalIndices: nil)
    }
    
    init(originalPageOffsets: [Int], data: [T], hintOriginalPageOffset: Int, hintOriginalIndices: [Int]?) {
        self.originalPageOffsets = originalPageOffsets
        self.data = data
        self.hintOriginalPageOffset = hintOriginalPageOffset
        self.hintOriginalIndices = hintOriginalIndices
        
        guard !originalPageOffsets.isEmpty else {
            fatalError("originalPageOffsets cannot be empty when constructing TranformablePage")
        }
        guard hintOriginalIndices == nil || hintOriginalIndices?.count == data.count else {
            fatalError("If originalIndices (count = \(hintOriginalIndices!.count) is provided, it must be same length as data (count = \(data.count)")
        }
    }
    
    static var EMPTY_INITIAL_PAGE: TransformablePage<T> {
        return TransformablePage<T>(originalPageOffset: 0, data: [])
    }
    
    static func empty<T: Any>() -> TransformablePage<T> {
        return EMPTY_INITIAL_PAGE as! TransformablePage<T>
    }
}

