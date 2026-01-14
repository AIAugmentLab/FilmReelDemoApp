//  ReelConfig.swift
//  FilmReelDemoApp
//
//  Created by Sun on 2026/1/13.
//

import UIKit

/// Reel 效果的可配置参数集合。
struct ReelConfig {
    /// Reel 阶段倒计时，结束后切换为统一滚动模式。
    var countdown: TimeInterval = 3.5
    /// Reel 自动滚动速度（pt/s），左右列方向相反。
    var reelSpeed: CGFloat = 60.0
    /// Reel 阶段默认起始位置（pt），避免从顶部开始导致右列不动；0 表示从顶部开始。
    var reelStartOffset: CGFloat = 360.0
    /// Reel 阶段左右列允许的最大错开距离（pt），0 表示不限制。
    var maxReelOffsetDelta: CGFloat = 0.0
    /// 预留的对齐缓动时长（当前版本为“同时停止”，不做对齐）。
    var alignDuration: TimeInterval = 0.2
    /// 内容最小高度倍率，低于此会重复填充，避免 Reel 时出现空白。
    var minFillMultiplier: CGFloat = 1.3
    /// 瀑布流整体内边距。
    var contentInset: UIEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    /// 左右列之间的横向间距。
    var columnSpacing: CGFloat = 12
    /// Item 之间的纵向间距。
    var itemSpacing: CGFloat = 12
}
