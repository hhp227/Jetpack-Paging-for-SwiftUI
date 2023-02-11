//
//  PageEvent.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/26.
//

import Foundation

open class PageEvent<T: Any> {
    class StaticList<T: Any>: PageEvent<T> {
        let data: [T]
        
        var sourceLoadStates: LoadStates? = nil
        
        var mediatorLoadStates: LoadStates? = nil
        
        init(data: [T], sourceLoadStates: LoadStates? = nil, mediatorLoadStates: LoadStates? = nil) {
            self.data = data
            self.sourceLoadStates = sourceLoadStates
            self.mediatorLoadStates = mediatorLoadStates
        }
    }

    class Insert<T: Any>: PageEvent<T> {
        let loadType: LoadType
        
        let pages: [TransformablePage<T>]
        
        let placeholdersBefore: Int
        
        let placeholdersAfter: Int
        
        let sourceLoadStates: LoadStates
        
        var mediatorLoadStates: LoadStates? = nil
        
        static func Refresh(
            pages: [TransformablePage<T>],
            placeholdersBefore: Int,
            placeholdersAfter: Int,
            sourceLoadStates: LoadStates,
            mediatorLoadStates: LoadStates? = nil
        ) -> Insert {
            return Insert(
                loadType: LoadType.REFRESH,
                pages: pages,
                placeholdersBefore: placeholdersBefore,
                placeholdersAfter: placeholdersAfter,
                sourceLoadStates: sourceLoadStates,
                mediatorLoadStates: mediatorLoadStates
            )
        }
        
        static func Prepend(
            pages: [TransformablePage<T>],
            placeholdersBefore: Int,
            sourceLoadStates: LoadStates,
            mediatorLoadStates: LoadStates? = nil
        ) -> Insert {
            return Insert(
                loadType: LoadType.PREPEND,
                pages: pages,
                placeholdersBefore: placeholdersBefore,
                placeholdersAfter: -1,
                sourceLoadStates: sourceLoadStates,
                mediatorLoadStates: mediatorLoadStates
            )
        }
        
        static func Append(
            pages: [TransformablePage<T>],
            placeholdersAfter: Int,
            sourceLoadStates: LoadStates,
            mediatorLoadStates: LoadStates? = nil
        ) -> Insert {
            return Insert(
                loadType: LoadType.APPEND,
                pages: pages,
                placeholdersBefore: -1,
                placeholdersAfter: placeholdersAfter,
                sourceLoadStates: sourceLoadStates,
                mediatorLoadStates: mediatorLoadStates
            )
        }
        
        private init(loadType: LoadType, pages: [TransformablePage<T>], placeholdersBefore: Int, placeholdersAfter: Int, sourceLoadStates: LoadStates, mediatorLoadStates: LoadStates? = nil) {
            self.loadType = loadType
            self.pages = pages
            self.placeholdersBefore = placeholdersBefore
            self.placeholdersAfter = placeholdersAfter
            self.sourceLoadStates = sourceLoadStates
            self.mediatorLoadStates = mediatorLoadStates
            
            guard loadType == .APPEND || placeholdersBefore >= 0 else {
                fatalError("Prepend insert defining placeholdersBefore must be > 0, but was \(placeholdersBefore)")
            }
            guard loadType == .PREPEND || placeholdersAfter >= 0 else {
                fatalError("Append insert defining placeholdersAfter must be > 0, but was \(placeholdersAfter)")
            }
            guard loadType == .REFRESH || !pages.isEmpty else {
                fatalError("Cannot create a REFRESH Insert event with no TransformablePages as this could permanently stall pagination. Note that this check does not prevent empty LoadResults and is instead usually an indication of an internal error in Paging itself.")
            }
        }
        
        static var EMPTY_REFRESH_LOCAL: Insert<Any> {
            Insert<Any>.Refresh(
                pages: [TransformablePage<Any>.EMPTY_INITIAL_PAGE],
                placeholdersBefore: 0,
                placeholdersAfter: 0,
                sourceLoadStates: LoadStates(.NotLoading(false), .NotLoading(true), .NotLoading(true))
            )
        }
    }
    
    class Drop<T: Any>: PageEvent<T> {
        let loadType: LoadType
        
        let minPageOffset: Int
        
        let maxPageOffset: Int
        
        let placeholdersRemaining: Int
        
        init(loadType: LoadType, minPageOffset: Int, maxPageOffset: Int, placeholdersRemaining: Int) {
            self.loadType = loadType
            self.minPageOffset = minPageOffset
            self.maxPageOffset = maxPageOffset
            self.placeholdersRemaining = placeholdersRemaining
            
            guard loadType != .REFRESH else {
                fatalError("Drop load type must be PREPEND or APPEND")
            }
            
            guard placeholdersRemaining >= 0 else {
                fatalError("Invalid placeholdersRemaining \(placeholdersRemaining)")
            }
        }
        
        var pageCount: Int {
            return maxPageOffset - minPageOffset + 1
        }
    }

    class LoadStateUpdate<T: Any>: PageEvent<T> {
        let source: LoadStates
        
        var mediator: LoadStates? = nil
        
        init(source: LoadStates, mediator: LoadStates? = nil) {
            self.source = source
            self.mediator = mediator
        }
    }
}
