//  ReelWaterfallView.swift
//  FilmReelDemoApp
//
//  Created by Sun on 2026/1/13.
//

import UIKit

/// Reel 瀑布流容器：Reel 阶段列级反向滚动，Unified 阶段统一滚动。
final class ReelWaterfallView: UIView {
    private enum Mode {
        /// Reel 阶段，左右列独立 offset。
        case reel
        /// 统一阶段，交由 collectionView 原生滚动。
        case unified
    }

    /// Reel 参数配置，修改后会触发布局刷新。
    var config: ReelConfig {
        didSet {
            applyConfig()
        }
    }

    /// 自定义瀑布流布局，负责计算基础 frames 并应用列级偏移。
    private let layout = ReelMasonryLayout()
    /// 统一滚动载体，所有 cell 复用均由它管理。
    private let collectionView: ReelCollectionView
    /// CADisplayLink 驱动器，用于 Reel 阶段的逐帧滚动。
    private let reelDriver = DisplayLinkDriver()
    /// 预留的数值缓动器（当前只做 stop，便于后续扩展平滑对齐）。
    private let alignAnimator = ValueAnimator()
    /// Reel 阶段倒计时，触发统一滚动切换。
    private var reelTimer: Timer?
    /// 原始数据源。
    private var items: [ReelItem] = []
    /// 实际展示数据，可能包含重复填充后的 items。
    private var displayItems: [ReelItem] = []
    /// 标记是否需要重建布局缓存。
    private var needsRebuild = true
    /// 最近一次布局的尺寸，用于判断是否需要重建。
    private var cachedBounds: CGSize = .zero
    /// 是否已预先准备 Reel 起始状态，用于避免首次显示跳动。
    private var hasPreparedReel = false
    /// 当前滚动模式。
    private var mode: Mode = .reel
    /// 过渡中保护，避免多次触发切换。
    private var isTransitioning = false
    /// 记录 Reel 结束时的偏移，统一滚动时逐步衰减到 0。
    private var unifiedLeftOffset: CGFloat = 0
    private var unifiedRightOffset: CGFloat = 0
    /// 统一滚动阶段的锚点 offset（用于无位移切换）。
    private var unifiedAnchorOffset: CGFloat = 0
    /// 一旦滚动到顶部，锁定列偏移为 0，避免再引入错位。
    private var unifiedOffsetsLocked = false
    /// 左列配色：偏暖色系。
    private let leftPalette: [UIColor] = [
        UIColor(red: 0.91, green: 0.36, blue: 0.27, alpha: 1.0),
        UIColor(red: 0.95, green: 0.55, blue: 0.25, alpha: 1.0),
        UIColor(red: 0.98, green: 0.73, blue: 0.28, alpha: 1.0),
        UIColor(red: 0.90, green: 0.42, blue: 0.46, alpha: 1.0)
    ]
    /// 右列配色：偏冷色系。
    private let rightPalette: [UIColor] = [
        UIColor(red: 0.18, green: 0.60, blue: 0.88, alpha: 1.0),
        UIColor(red: 0.20, green: 0.74, blue: 0.67, alpha: 1.0),
        UIColor(red: 0.26, green: 0.65, blue: 0.49, alpha: 1.0),
        UIColor(red: 0.20, green: 0.52, blue: 0.76, alpha: 1.0)
    ]

    override init(frame: CGRect) {
        self.config = ReelConfig()
        self.collectionView = ReelCollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        configureView()
    }

    init(config: ReelConfig) {
        self.config = config
        self.collectionView = ReelCollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        reelDriver.stop()
        alignAnimator.stop()
        reelTimer?.invalidate()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.frame = bounds
        if bounds.size != cachedBounds {
            cachedBounds = bounds.size
            needsRebuild = true
            rebuildDisplayItemsIfPossible()
            if mode == .reel && !isTransitioning {
                // 尺寸变化时重置 Reel 偏移，防止错位
                resetOffsetsForReel()
            }
        }
    }

    /// 更新数据源并触发布局刷新。
    func reloadData(items: [ReelItem]) {
        self.items = items
        needsRebuild = true
        hasPreparedReel = false
        collectionView.isHidden = true
        rebuildDisplayItemsIfPossible()
    }

    /// 预先准备 Reel 起始状态（不启动倒计时/动画），避免首次显示跳动。
    func prepareReelStart() {
        guard !items.isEmpty else { return }
        mode = .reel
        isTransitioning = false
        alignAnimator.stop()
        resetUnifiedState()
        rebuildDisplayItemsIfPossible(force: true)
        collectionView.layoutIfNeeded()
        resetOffsetsForReel()
        collectionView.setContentOffset(.zero, animated: false)
        // 立即应用起始偏移，避免首帧仍显示在顶部
        collectionView.layoutIfNeeded()
        collectionView.isHidden = false
        hasPreparedReel = true
    }

    /// 进入 Reel 阶段：启动自动滚动与倒计时，触摸后切换为统一滚动。
    func startReel() {
        guard !items.isEmpty else { return }
        if !hasPreparedReel {
            prepareReelStart()
        } else {
            mode = .reel
            isTransitioning = false
            alignAnimator.stop()
            resetUnifiedState()
            // 如果准备阶段未命中起始偏移，再次确保落在配置的起点
            if config.reelStartOffset > 0,
               layout.leftOffset == 0,
               layout.rightOffset == 0 {
                resetOffsetsForReel()
                collectionView.layoutIfNeeded()
            }
            collectionView.isHidden = false
        }
        startCountdown()
        reelDriver.start()
    }

    /// 外部手动停止 Reel 阶段。
    func stopReel() {
        transitionToUnified()
    }

    /// 从当前可见位置继续播放 Reel 动画与倒计时。
    func resumeReel() {
        guard !items.isEmpty else { return }
        alignAnimator.stop()
        reelTimer?.invalidate()
        reelDriver.stop()

        if mode == .reel {
            // 已在 Reel 模式，仅重启倒计时即可
            startCountdown()
            reelDriver.start()
            return
        }

        // 将 unified 的 contentOffset 合并到列偏移里，保证视觉位置不变
        updateUnifiedOffsetsForScroll()
        let currentOffset = collectionView.contentOffset.y
        let maxOffset = maxOffsetForReel()
        let nextLeftOffset = min(max(layout.leftOffset + currentOffset, 0), maxOffset)
        let nextRightOffset = min(max(layout.rightOffset + currentOffset, 0), maxOffset)

        // 先切到 Reel 模式，避免 setContentOffset 触发的回调改写列偏移
        mode = .reel
        isTransitioning = false

        UIView.performWithoutAnimation {
            collectionView.setContentOffset(.zero, animated: false)
            layout.leftOffset = nextLeftOffset
            layout.rightOffset = nextRightOffset
            layout.invalidateLayout()
            collectionView.layoutIfNeeded()
        }
        resetUnifiedState()
        startCountdown()
        reelDriver.start()
    }

    private func configureView() {
        backgroundColor = .clear

        layout.contentInset = config.contentInset
        layout.columnSpacing = config.columnSpacing
        layout.itemSpacing = config.itemSpacing

        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = true
        collectionView.contentInsetAdjustmentBehavior = .never
        // 首次进入前先隐藏，准备好起始偏移后再显示，避免可见跳动
        collectionView.isHidden = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ReelCell.self, forCellWithReuseIdentifier: ReelCell.reuseIdentifier)
        addSubview(collectionView)

        // 捕获触摸起始，触发 Reel → Unified 切换
        collectionView.onTouchBegan = { [weak self] in
            self?.handleTouchBegan()
        }

        // Reel 帧驱动回调
        reelDriver.tick = { [weak self] dt in
            self?.advanceReel(by: dt)
        }
    }

    private func applyConfig() {
        // 配置更新后需重新计算布局
        layout.contentInset = config.contentInset
        layout.columnSpacing = config.columnSpacing
        layout.itemSpacing = config.itemSpacing
        needsRebuild = true
        hasPreparedReel = false
        rebuildDisplayItemsIfPossible(force: true)
    }

    private func rebuildDisplayItemsIfPossible(force: Bool = false) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        guard !items.isEmpty else {
            displayItems = []
            layout.itemHeights = []
            collectionView.reloadData()
            return
        }
        if !force && !needsRebuild && cachedBounds == bounds.size {
            return
        }

        cachedBounds = bounds.size
        // 确保 Reel 阶段内容足够高，避免短列表出现空白
        displayItems = buildDisplayItems(minHeight: bounds.height * config.minFillMultiplier, width: bounds.width)
        layout.itemHeights = displayItems.map { $0.height }
        layout.invalidateLayout()
        collectionView.reloadData()
        needsRebuild = false
    }

    private func buildDisplayItems(minHeight: CGFloat, width: CGFloat) -> [ReelItem] {
        var output = items
        var heights = items.map { $0.height }
        var contentHeight = measureContentHeight(for: heights, width: width)
        var iterations = 0
        // 循环追加 items，直到内容高度满足阈值
        while contentHeight < minHeight && iterations < 20 {
            output.append(contentsOf: items)
            heights.append(contentsOf: items.map { $0.height })
            contentHeight = measureContentHeight(for: heights, width: width)
            iterations += 1
        }
        return output
    }

    private func measureContentHeight(for heights: [CGFloat], width: CGFloat) -> CGFloat {
        // 复用布局计算逻辑，只取 contentHeight
        let result = ReelMasonryLayout.buildFrames(
            heights: heights,
            containerWidth: width,
            contentInset: layout.contentInset,
            columnSpacing: layout.columnSpacing,
            itemSpacing: layout.itemSpacing
        )
        return result.contentHeight
    }

    private func startCountdown() {
        reelTimer?.invalidate()
        // Reel 倒计时结束后切换为统一滚动
        reelTimer = Timer.scheduledTimer(withTimeInterval: config.countdown, repeats: false) { [weak self] _ in
            self?.transitionToUnified()
        }
    }

    private func resetOffsetsForReel() {
        let maxOffset = maxOffsetForReel()
        // 起始位置可配置，左右列起点一致，避免顶部人为错位
        let startOffset = min(max(config.reelStartOffset, 0), maxOffset)
        layout.leftOffset = startOffset
        layout.rightOffset = startOffset
        layout.invalidateLayout()
    }

    private func maxOffsetForReel() -> CGFloat {
        // 列偏移的最大值 = 内容高度 - 可视高度
        max(0, layout.contentHeight - collectionView.bounds.height)
    }

    private func advanceReel(by dt: CFTimeInterval) {
        guard mode == .reel, !isTransitioning else { return }
        let maxOffset = maxOffsetForReel()
        guard maxOffset > 0 else { return }
        let delta = config.reelSpeed * CGFloat(dt)
        var step = delta
        // 只限制“继续扩大错位”的步长，避免中途回拉导致跳动
        let maxDelta = max(0, config.maxReelOffsetDelta)
        if maxDelta > 0 {
            let currentDelta = layout.leftOffset - layout.rightOffset
            let remaining = maxDelta - currentDelta
            if remaining <= 0 {
                step = 0
            } else {
                // 左右列各走 step，会让差值增加 2*step
                step = min(step, remaining * 0.5)
            }
        }
        if step <= 0 {
            return
        }

        // 左列递增、右列递减，右列到顶后保持不动
        layout.leftOffset = min(layout.leftOffset + step, maxOffset)
        layout.rightOffset = max(layout.rightOffset - step, 0)
        layout.invalidateLayout()
    }

    private func transitionToUnified() {
        guard mode == .reel, !isTransitioning else { return }
        isTransitioning = true
        // 结束 Reel 动画与计时，放开原生滚动
        reelDriver.stop()
        reelTimer?.invalidate()
        alignAnimator.stop()
        // 结束 Reel 后保持当前两列位置，不产生可见位移
        unifiedOffsetsLocked = false
        unifiedAnchorOffset = min(layout.leftOffset, layout.rightOffset)
        unifiedLeftOffset = layout.leftOffset - unifiedAnchorOffset
        unifiedRightOffset = layout.rightOffset - unifiedAnchorOffset
        layout.leftOffset = unifiedLeftOffset
        layout.rightOffset = unifiedRightOffset
        collectionView.setContentOffset(CGPoint(x: 0, y: unifiedAnchorOffset), animated: false)
        layout.invalidateLayout()
        finishUnified()
        updateUnifiedOffsetsForScroll()
    }

    private func finishUnified() {
        // 进入统一滚动模式
        mode = .unified
        isTransitioning = false
        collectionView.isScrollEnabled = true
    }

    private func resetUnifiedState() {
        unifiedAnchorOffset = 0
        unifiedLeftOffset = 0
        unifiedRightOffset = 0
        unifiedOffsetsLocked = false
    }

    private func updateUnifiedOffsetsForScroll() {
        guard mode == .unified else { return }
        if unifiedOffsetsLocked {
            return
        }
        let anchor = unifiedAnchorOffset
        if collectionView.contentOffset.y <= 0 {
            // 一旦到达顶部，锁定两列偏移为 0，后续滚动保持同步速度
            layout.leftOffset = 0
            layout.rightOffset = 0
            unifiedOffsetsLocked = true
            layout.invalidateLayout()
            return
        }
        guard anchor > 0 else {
            layout.leftOffset = 0
            layout.rightOffset = 0
            layout.invalidateLayout()
            return
        }
        // 在向上滚动的过程中逐步消除列偏移，避免切换瞬间跳动
        let factor = min(max(collectionView.contentOffset.y / anchor, 0), 1)
        layout.leftOffset = unifiedLeftOffset * factor
        layout.rightOffset = unifiedRightOffset * factor
        layout.invalidateLayout()
    }

    private func colorForItem(at indexPath: IndexPath) -> UIColor? {
        // 按列分配不同色系，形成左右列差异化视觉分布
        let column = layout.columnIndex(for: indexPath.item) ?? 0
        if column == 0 {
            return leftPalette[indexPath.item % leftPalette.count]
        }
        return rightPalette[indexPath.item % rightPalette.count]
    }

    private func handleTouchBegan() {
        guard mode == .reel, !isTransitioning else { return }
        // 触摸立即触发切换
        transitionToUnified()
    }
}

extension ReelWaterfallView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        displayItems.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReelCell.reuseIdentifier,
                                                      for: indexPath)
        guard let reelCell = cell as? ReelCell else { return cell }
        reelCell.configure(with: displayItems[indexPath.item], colorOverride: colorForItem(at: indexPath))
        reelCell.onTouchBegan = { [weak self] in
            self?.handleTouchBegan()
        }
        return reelCell
    }
}

extension ReelWaterfallView: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateUnifiedOffsetsForScroll()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // 防止触摸回调未命中时漏切换，确保拖动即可进入统一模式
        handleTouchBegan()
    }
}

/// 自定义 CollectionView：触摸开始时回调，用于停止 Reel 动画。
private final class ReelCollectionView: UICollectionView {
    var onTouchBegan: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTouchBegan?()
        super.touchesBegan(touches, with: event)
    }
}

/// CADisplayLink 封装：提供与屏幕刷新同步的 dt。
private final class DisplayLinkDriver {
    var tick: ((CFTimeInterval) -> Void)?
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    func start() {
        stop()
        lastTimestamp = 0
        // CADisplayLink 驱动帧回调
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
    }

    @objc private func step(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }
        // 计算上一帧到当前帧的时间差
        let dt = link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp
        tick?(dt)
    }
}

/// 简单的数值缓动器，适合做 offset 过渡。
private final class ValueAnimator {
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var duration: TimeInterval = 0
    private var fromValue: CGFloat = 0
    private var toValue: CGFloat = 0
    private var update: ((CGFloat) -> Void)?
    private var completion: (() -> Void)?

    func start(from: CGFloat,
               to: CGFloat,
               duration: TimeInterval,
               update: @escaping (CGFloat) -> Void,
               completion: @escaping () -> Void) {
        stop()
        self.fromValue = from
        self.toValue = to
        self.duration = max(0.0001, duration)
        self.update = update
        self.completion = completion
        startTime = 0
        // 简单数值缓动器，可用于过渡动画
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        update = nil
        completion = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        if startTime == 0 {
            startTime = link.timestamp
            update?(fromValue)
            return
        }
        let elapsed = link.timestamp - startTime
        let progress = min(1, elapsed / duration)
        // easeOutCubic，确保收尾平滑
        let eased = 1 - pow(1 - progress, 3)
        let value = fromValue + (toValue - fromValue) * CGFloat(eased)
        update?(value)
        if progress >= 1 {
            let completion = completion
            stop()
            completion?()
        }
    }
}
