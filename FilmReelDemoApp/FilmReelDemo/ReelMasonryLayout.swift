//  ReelMasonryLayout.swift
//  FilmReelDemoApp
//
//  Created by Sun on 2026/1/13.
//

import UIKit

/// 两列瀑布流布局，支持 Reel 模式的列级偏移。
final class ReelMasonryLayout: UICollectionViewLayout {
    /// 每个 item 的高度输入，外部传入。
    var itemHeights: [CGFloat] = []
    /// 内容内边距。
    var contentInset: UIEdgeInsets = .zero
    /// 两列之间的横向间距。
    var columnSpacing: CGFloat = 0
    /// item 之间的纵向间距。
    var itemSpacing: CGFloat = 0
    /// Reel 模式左列的“虚拟 offset”。
    var leftOffset: CGFloat = 0
    /// Reel 模式右列的“虚拟 offset”。
    var rightOffset: CGFloat = 0

    /// 缓存的基础 attributes（不含 Reel 偏移）。
    private var cache: [UICollectionViewLayoutAttributes] = []
    /// 每个 item 对应的列（0 左 / 1 右）。
    private var columnForItem: [Int] = []
    /// 缓存构建时的容器尺寸，用于判断是否需要重建。
    private var cachedSize: CGSize = .zero
    /// 缓存构建时的 item 数量，用于判断是否需要重建。
    private var cachedItemCount: Int = 0
    /// 计算后的内容总高度（不含 Reel 偏移）。
    private(set) var contentHeight: CGFloat = 0

    /// 返回指定 item 的列索引（0 左 / 1 右），用于外部配色。
    func columnIndex(for item: Int) -> Int? {
        guard item >= 0, item < columnForItem.count else { return nil }
        return columnForItem[item]
    }

    override func prepare() {
        super.prepare()
        guard let collectionView else { return }
        let size = collectionView.bounds.size
        // 尺寸或数据变化时重建布局缓存，避免重复计算。
        if cache.isEmpty || size != cachedSize || cachedItemCount != itemHeights.count {
            rebuildCache(in: size)
        }
    }

    override var collectionViewContentSize: CGSize {
        guard let collectionView else { return .zero }
        return CGSize(width: collectionView.bounds.width, height: contentHeight)
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard !cache.isEmpty else { return [] }
        var visible: [UICollectionViewLayoutAttributes] = []
        visible.reserveCapacity(cache.count)
        for attributes in cache {
            let column = columnForItem[attributes.indexPath.item]
            let offset = (column == 0) ? leftOffset : rightOffset
            let adjusted = attributes.copy() as! UICollectionViewLayoutAttributes
            // Reel 模式用列级偏移模拟独立滚动
            adjusted.frame.origin.y -= offset
            if adjusted.frame.intersects(rect) {
                visible.append(adjusted)
            }
        }
        return visible
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.item < cache.count else { return nil }
        let base = cache[indexPath.item]
        let column = columnForItem[indexPath.item]
        let offset = (column == 0) ? leftOffset : rightOffset
        let adjusted = base.copy() as! UICollectionViewLayoutAttributes
        // 单个 item 也需要应用列级偏移
        adjusted.frame.origin.y -= offset
        return adjusted
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        // 仅在尺寸变化时重建，滚动时不重建 cache
        return newBounds.size != cachedSize
    }

    private func rebuildCache(in size: CGSize) {
        cachedSize = size
        cachedItemCount = itemHeights.count
        cache.removeAll(keepingCapacity: true)
        columnForItem.removeAll(keepingCapacity: true)

        // 先计算基础瀑布流 frames（不含 Reel 偏移），再缓存 attributes。
        let result = Self.buildFrames(
            heights: itemHeights,
            containerWidth: size.width,
            contentInset: contentInset,
            columnSpacing: columnSpacing,
            itemSpacing: itemSpacing
        )
        contentHeight = result.contentHeight
        columnForItem = result.columns

        for (index, frame) in result.frames.enumerated() {
            let indexPath = IndexPath(item: index, section: 0)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = frame
            cache.append(attributes)
        }
    }

    static func buildFrames(heights: [CGFloat],
                            containerWidth: CGFloat,
                            contentInset: UIEdgeInsets,
                            columnSpacing: CGFloat,
                            itemSpacing: CGFloat) -> (frames: [CGRect], columns: [Int], contentHeight: CGFloat) {
        guard containerWidth > 0 else { return ([], [], 0) }
        // 仅计算基础瀑布流布局，不包含 Reel 偏移
        let availableWidth = containerWidth - contentInset.left - contentInset.right - columnSpacing
        let columnWidth = max(0, availableWidth / 2)
        var frames: [CGRect] = []
        var columns: [Int] = []
        frames.reserveCapacity(heights.count)
        columns.reserveCapacity(heights.count)

        // 采用“短列优先”策略，保证左右列高度尽量均衡
        var columnHeights: [CGFloat] = [contentInset.top, contentInset.top]

        for height in heights {
            let column = columnHeights[0] <= columnHeights[1] ? 0 : 1
            let x = contentInset.left + CGFloat(column) * (columnWidth + columnSpacing)
            let y = columnHeights[column]
            let frame = CGRect(x: x, y: y, width: columnWidth, height: height)
            frames.append(frame)
            columns.append(column)
            columnHeights[column] = frame.maxY + itemSpacing
        }

        let maxColumn = max(columnHeights[0], columnHeights[1])
        let contentHeight: CGFloat
        if heights.isEmpty {
            contentHeight = contentInset.top + contentInset.bottom
        } else {
            // 取最高列高度，去掉最后一次 itemSpacing，再加底部 inset
            contentHeight = maxColumn - itemSpacing + contentInset.bottom
        }
        return (frames, columns, contentHeight)
    }
}
