//  HomeViewController.swift
//  FilmReelDemoApp
//
//  Created by Sun on 2026/1/13.
//

import UIKit

/// Demo 入口页：作为一级页面，引导进入 Reel 瀑布流。
final class HomeViewController: UIViewController {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let openButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Demo Home"

        configureViews()
        layoutViews()
    }

    private func configureViews() {
        // 主标题
        titleLabel.text = "Film Reel Demo"
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        // 副标题
        subtitleLabel.text = "进入双列电影放映带瀑布流"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        // 入口按钮
        openButton.setTitle("Open Reel", for: .normal)
        openButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        openButton.addTarget(self, action: #selector(openReel), for: .touchUpInside)
    }

    private func layoutViews() {
        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, openButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    @objc private func openReel() {
        // 进入二级页面
        let controller = ReelWaterfallViewController()
        navigationController?.pushViewController(controller, animated: true)
    }
}
