//  ReelItem.swift
//  FilmReelDemoApp
//
//  Created by Sun on 2026/1/13.
//

import UIKit

struct ReelItem: Hashable {
    let id: UUID
    let height: CGFloat
    let title: String
    let color: UIColor

    init(id: UUID = UUID(), height: CGFloat, title: String, color: UIColor) {
        self.id = id
        self.height = height
        self.title = title
        self.color = color
    }
}
