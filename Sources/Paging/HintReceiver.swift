//
//  HintReceiver.swift
//  Paging
//
//  Created by 홍희표 on 2024/06/27.
//

import Foundation

internal protocol HintReceiver {
    func accessHint(viewportHint: ViewportHint)
}
