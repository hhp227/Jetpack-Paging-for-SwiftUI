//
//  CachedPageEventPublisher.swift
//  Application
//
//  Created by hhp227 on 6/11/24.
//

import Foundation
import Combine

internal class CachedPageEventPublisher<T: Any> {
    private let pageController = FlattenedPageController<T>()
    private let mutableSharedSrc = CurrentValueSubject<(index: Int, value: PageEvent<T>)?, Never>(nil)
    private var cancellables = Set<AnyCancellable>()
    private let upstream: AnyPublisher<PageEvent<T>, Never>

    private lazy var sharedForDownstream: AnyPublisher<(index: Int, value: PageEvent<T>)?, Never> = {
        mutableSharedSrc
            .handleEvents(receiveSubscription: { _ in
                let history = self.pageController.getStateAsEvents()
                self.job.store(in: &self.cancellables)
                history.forEach { self.mutableSharedSrc.send($0) }
            })
            .share()
            .eraseToAnyPublisher()
    }()

    private lazy var job: AnyCancellable = upstream
        .withIndex()
        .sink(receiveCompletion: { _ in self.mutableSharedSrc.send(nil) }, receiveValue: { self.mutableSharedSrc.send($0) })

    func close() {
        job.cancel()
    }

    lazy var downstreamPublisher = {
        let downstreamSubject = PassthroughSubject<PageEvent<T>, Never>()
        var maxEventIndex = Int.min

        sharedForDownstream
            .prefix(while: { $0 != nil })
            .sink { indexedValue in
                if indexedValue!.index > maxEventIndex {
                    downstreamSubject.send(indexedValue!.value)
                    maxEventIndex = indexedValue!.index
                }
            }
            .store(in: &self.cancellables)
        return downstreamSubject.eraseToAnyPublisher()
    }()

    init(src: AnyPublisher<PageEvent<T>, Never>) {
        self.upstream = src
    }
}

private class FlattenedPageController<T: Any> {
    private let list = FlattenedPageEventStorage<T>()
    private let lock = NSLock()
    private var maxEventIndex = -1

    func record(_ event: EnumeratedSequence<[PageEvent<T>]>.Element) {
        lock.withLock {
            maxEventIndex = event.offset
            list.append(event.element)
        }
    }

    func getStateAsEvents() -> [(index: Int, value: PageEvent<T>)] {
        return lock.withLock {
            let catchupEvents = list.getAsEvents()
            let startEventIndex = maxEventIndex - catchupEvents.count + 1
            return catchupEvents.enumerated().map { (index, pageEvent) in
                (index: startEventIndex + index, value: pageEvent)
            }
        }
    }
}

internal class FlattenedPageEventStorage<T: Any> {
    private var placeholdersBefore = 0
    private var placeholdersAfter = 0
    private var pages = [TransformablePage<T>]()
    private var sourceStates = MutableLoadStateCollection()
    private var mediatorStates: LoadStates?
    private var receivedFirstEvent = false

    func append(_ event: PageEvent<T>) {
        receivedFirstEvent = true
        switch event {
        case let insert as PageEvent<T>.Insert<T>:
            handleInsert(insert)
        case let drop as PageEvent<T>.Drop<T>:
            handlePageDrop(drop)
        case let loadStateUpdate as PageEvent<T>.LoadStateUpdate<T>:
            handleLoadStateUpdate(loadStateUpdate)
        default:
            break
        }
    }

    private func handlePageDrop(_ event: PageEvent<T>.Drop<T>) {
        sourceStates.set(event.loadType, .NotLoading(false))
        switch event.loadType {
        case .prepend:
            placeholdersBefore = event.placeholdersRemaining
            pages.removeFirst(event.pageCount)
        case .append:
            placeholdersAfter = event.placeholdersRemaining
            pages.removeLast(event.pageCount)
        default:
            fatalError("Page drop type must be prepend or append")
        }
    }

    private func handleInsert(_ event: PageEvent<T>.Insert<T>) {
        sourceStates.set(event.sourceLoadStates)
        mediatorStates = event.mediatorLoadStates

        switch event.loadType {
        case .refresh:
            pages.removeAll()
            placeholdersAfter = event.placeholdersAfter
            placeholdersBefore = event.placeholdersBefore
            pages.append(contentsOf: event.pages)
        case .prepend:
            placeholdersBefore = event.placeholdersBefore
            pages.insert(contentsOf: event.pages.reversed(), at: 0)
        case .append:
            placeholdersAfter = event.placeholdersAfter
            pages.append(contentsOf: event.pages)
        }
    }

    private func handleLoadStateUpdate(_ event: PageEvent<T>.LoadStateUpdate<T>) {
        sourceStates.set(event.source)
        mediatorStates = event.mediator
    }

    func getAsEvents() -> [PageEvent<T>] {
        guard receivedFirstEvent else { return [] }
        var events = [PageEvent<T>]()
        let source = sourceStates.snapshot()
        if !pages.isEmpty {
            events.append(
                PageEvent<T>.Insert.Refresh(
                    pages: pages,
                    placeholdersBefore: placeholdersBefore,
                    placeholdersAfter: placeholdersAfter,
                    sourceLoadStates: source,
                    mediatorLoadStates: mediatorStates
                )
            )
        } else {
            events.append(
                PageEvent<T>.LoadStateUpdate(
                    source: source,
                    mediator: mediatorStates
                )
            )
        }
        return events
    }
}

extension Publisher {
    func withIndex() -> AnyPublisher<(index: Int, value: Output), Failure> {
        self.scan((index: -1, value: nil as Output?)) { (accum, current) in
            (index: accum.index + 1, value: current)
        }
        .compactMap { (index, value) in
            value.map { (index: index, value: $0) }
        }
        .eraseToAnyPublisher()
    }
}
