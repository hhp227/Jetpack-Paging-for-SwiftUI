//
//  UiReceiver.swift
//  Paging
//
//  Created by 홍희표 on 2022/06/19.
//

import Foundation

internal protocol UiReceiver {
    func accessHint(viewportHint: ViewportHint)
    
    func retry()
    
    func refresh()
}
