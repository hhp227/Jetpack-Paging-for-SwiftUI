//
//  PageEvent.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/26.
//

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
        
        private func mapPages<R: Any>(_ transform: @escaping (TransformablePage<T>) -> TransformablePage<R>) -> Insert<R> {
            return transformPages { pages in
                pages.map(transform)
            }
        }
        
        internal func transformPages<R: Any>(_ transform: @escaping ([TransformablePage<T>]) -> [TransformablePage<R>]) -> Insert<R> {
            return Insert<R>(
                loadType: loadType,
                pages: transform(pages),
                placeholdersBefore: placeholdersBefore,
                placeholdersAfter: placeholdersAfter,
                sourceLoadStates: sourceLoadStates,
                mediatorLoadStates: mediatorLoadStates
            )
        }
        
        override func map<R>(_ transform: @escaping (T) -> R) -> PageEvent<R> {
            return mapPages {
                TransformablePage(
                    originalPageOffsets: $0.originalPageOffsets,
                    data: $0.data.map(transform),
                    hintOriginalPageOffset: $0.hintOriginalPageOffset,
                    hintOriginalIndices: $0.hintOriginalIndices
                )
            }
        }
        
        override func flatMap<R>(_ transform: @escaping (T) -> [R]) -> PageEvent<R> {
            return mapPages { transformPage in
                var data = [R]()
                var originalIndices = [Int]()
                transformPage.data.enumerated().forEach { (offset, element) in
                    data.append(contentsOf: transform(element))
                    let indexToStore = transformPage.hintOriginalIndices?[offset] ?? offset
                    while originalIndices.count < data.count {
                        originalIndices.append(indexToStore)
                    }
                }
                return TransformablePage(
                    originalPageOffsets: transformPage.originalPageOffsets,
                    data: data,
                    hintOriginalPageOffset: transformPage.hintOriginalPageOffset,
                    hintOriginalIndices: originalIndices
                )
            }
        }
        
        override func filter(_ predicate: @escaping (T) -> Bool) -> PageEvent<T> {
            return mapPages { transformPage in
                var data = [T]()
                var originalIndices = [Int]()
                transformPage.data.enumerated().forEach { (index, t) in
                    if predicate(t) {
                        data.append(t)
                        originalIndices.append(transformPage.hintOriginalIndices?[index] ?? index)
                    }
                }
                return TransformablePage(
                    originalPageOffsets: transformPage.originalPageOffsets,
                    data: data,
                    hintOriginalPageOffset: transformPage.hintOriginalPageOffset,
                    hintOriginalIndices: originalIndices
                )
            }
        }
        
        static func Refresh(
            pages: [TransformablePage<T>],
            placeholdersBefore: Int,
            placeholdersAfter: Int,
            sourceLoadStates: LoadStates,
            mediatorLoadStates: LoadStates? = nil
        ) -> Insert {
            return Insert(
                loadType: .refresh,
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
                loadType: .prepend,
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
                loadType: .append,
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
            
            guard loadType == .append || placeholdersBefore >= 0 else {
                fatalError("Prepend insert defining placeholdersBefore must be > 0, but was \(placeholdersBefore)")
            }
            guard loadType == .prepend || placeholdersAfter >= 0 else {
                fatalError("Append insert defining placeholdersAfter must be > 0, but was \(placeholdersAfter)")
            }
            guard loadType == .refresh || !pages.isEmpty else {
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
            
            guard loadType != .refresh else {
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
    
    open func map<R: Any>(_ transform: @escaping (T) -> R) -> PageEvent<R> {
        return self as! PageEvent<R>
    }
    
    open func flatMap<R: Any>(_ transform: @escaping (T) -> [R]) -> PageEvent<R> {
        return self as! PageEvent<R>
    }
    
    open func filter(_ predicate: @escaping (T) -> Bool) -> PageEvent<T> {
        return self
    }
}
