//  ReelWaterfallViewController.swift
//  FilmReelDemoApp
//
//  Created by Sun on 2026/1/13.
//

import UIKit

final class ReelWaterfallViewController: UIViewController {
    private let reelView = ReelWaterfallView()
    private var didPrepareInitialReel = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Film Reel"

        view.addSubview(reelView)
        reelView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            reelView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            reelView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            reelView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            reelView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        reelView.reloadData(items: makeDemoItems())

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Resume Reel",
            style: .plain,
            target: self,
            action: #selector(resumeReel)
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reelView.startReel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 首次出现前先布局并准备，避免进入时可见跳动
        if !didPrepareInitialReel {
            didPrepareInitialReel = true
            view.layoutIfNeeded()
            reelView.prepareReelStart()
        }
    }

    @objc private func resumeReel() {
        reelView.resumeReel()
    }

    private func makeDemoItems() -> [ReelItem] {
        let heights: [CGFloat] = [140, 180, 220, 160, 200, 150, 210]
        var items: [ReelItem] = []
        items.reserveCapacity(120)

        for index in 0..<120 {
            let height = heights[index % heights.count]
            let hue = CGFloat(index) / 120.0
            let color = UIColor(hue: hue, saturation: 0.6, brightness: 0.85, alpha: 1.0)
            items.append(ReelItem(height: height, title: "Movie \(index + 1)", color: color))
        }

        return items
    }
}
