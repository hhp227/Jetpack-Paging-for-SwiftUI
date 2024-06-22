//
//  LazyPagingItems.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

import Foundation
import Combine
import SwiftUI

public class LazyPagingItems<T : Any>: ObservableObject, DifferCallback {
    private let publisher: any Publisher<PagingData<T>, Never>
    
    @Published private(set) var itemSnapshotList = ItemSnapshotList<T>(0, 0, [])
    
    var itemCount: Int {
        get {
            return itemSnapshotList.count
        }
    }
    
    private lazy var pagingDataDiffer: PagingDataDiffer<T> = PagingDataDiffer<T>(
        differCallback: self,
        updateItemSnapshotList: updateItemSnapshotList
    )
    
    private var subscriptions = Set<AnyCancellable>()
    
    private func updateItemSnapshotList() {
        self.itemSnapshotList = self.pagingDataDiffer.snapshot()
    }
    
    func get(_ index: Int) -> T? {
        let _ = pagingDataDiffer.get(index: index)
        return itemSnapshotList[index]
    }
    
    func peek(_ index: Int) -> T? {
        return itemSnapshotList[index]
    }
    
    func retry() {
        pagingDataDiffer.retry()
    }
    
    func refresh() {
        pagingDataDiffer.refresh()
    }
    
    @Published public private(set) var loadState: CombinedLoadStates = CombinedLoadStates(
        refresh: InitialLoadStates.refresh,
        prepend: InitialLoadStates.prepend,
        append: InitialLoadStates.append
    )
    
    internal func collectLoadState() {
        pagingDataDiffer.loadStatePublisher.assign(to: \.loadState, on: self).store(in: &subscriptions)
    }
    
    internal func collectPagingData() {
        publisher.sink(receiveValue: self.pagingDataDiffer.collectFrom).store(in: &subscriptions)
    }
    
    func onChanged(_ position: Int, _ count: Int) {
        if count > 0 {
            updateItemSnapshotList()
        }
    }
    
    func onInserted(_ position: Int, _ count: Int) {
        if count > 0 {
            updateItemSnapshotList()
        }
    }
    
    func onRemoved(_ position: Int, _ count: Int) {
        if count > 0 {
            updateItemSnapshotList()
        }
    }
    
    init(_ publisher: any Publisher<PagingData<T>, Never>) {
        self.publisher = publisher
    }
}

private let InitialLoadStates = LoadStates(.Loading.instance, .NotLoading(false), .NotLoading(false))

extension Publisher where Failure == Never {
    public 
    func collectAsLazyPagingItems<T>() -> LazyPagingItems<T> where Output == PagingData<T> {
        @State var lazyPagingItems = LazyPagingItems(self)
        
        DispatchQueue.main.async {
            lazyPagingItems.collectPagingData()
        }
        DispatchQueue.main.async {
            lazyPagingItems.collectLoadState()
        }
        return lazyPagingItems
    }
}

extension ForEach where Data == Range<Int>, ID == Int, Content : View {
    public init<T>(_ data: LazyPagingItems<T>, @ViewBuilder content: @escaping (T?) -> Content) {
        print("???? \(data.itemCount)")
        self.init(0..<data.itemCount, id: \.self) { index in
            content(data.get(index))
        }
    }
}
