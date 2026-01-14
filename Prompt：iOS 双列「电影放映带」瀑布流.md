# Prompt：iOS 双列「电影放映带」瀑布流

目标：用 UIKit 实现 iOS 16 可运行 Demo，复刻当前代码的 Reel/Unified 行为与页面结构。

## 页面结构
- UIKit + SceneDelegate。
- 根控制器：`UINavigationController`。
- 一级页 `HomeViewController`：标题 `Demo Home`，中间有 `Open Reel` 按钮，push 到二级。
- 二级页 `ReelWaterfallViewController`：标题 `Film Reel`，右上角按钮 `Resume Reel`。

## Reel/Unified 行为
- **Reel 模式**：左右列独立 offset。
  - `leftOffset += speed * dt`，`rightOffset -= speed * dt`。
  - 右列到顶（offset=0）后保持不动。
  - 倒计时结束或触摸/拖动开始即切换 Unified。
- **Unified 模式**：两列共享 `contentOffset`，拖动同步滚动。
  - 回到顶部后锁定 `left/rightOffset = 0`，确保后续同步速度一致。

## 触摸与拖动
- 不用长按手势（避免必须抬手）。
- 触摸开始触发切换：
  - `UICollectionView` 子类 `touchesBegan` 回调。
  - `UICollectionViewCell` 子类 `touchesBegan` 回调。
  - 兜底：`scrollViewWillBeginDragging` 触发切换。
- Reel 阶段 **不要禁用** `isScrollEnabled`。

## 无位移切换（必须）
Reel → Unified 切换时保持视觉位置不变：
1. `anchor = min(leftOffset, rightOffset)`
2. `unifiedLeft = leftOffset - anchor`，`unifiedRight = rightOffset - anchor`
3. `contentOffset.y = anchor`，layout 用 `unifiedLeft/unifiedRight`
4. Unified 滚动时按进度衰减偏移：
   - `factor = contentOffset.y / anchor`
   - `leftOffset = unifiedLeft * factor`，`rightOffset = unifiedRight * factor`
5. 到顶部后锁定 offset 为 0。

## Resume 行为
- 点击 `Resume Reel`：从当前位置继续 Reel，不回到顶部。
- Unified → Reel 时合并 offset：
  - `currentOffset = contentOffset.y`
  - `nextLeft = layout.leftOffset + currentOffset`
  - `nextRight = layout.rightOffset + currentOffset`
  - `contentOffset = 0`，layout 设为 `nextLeft/nextRight`，然后启动 Reel + 倒计时。

## 起始偏移与防跳动
- 配置 `reelStartOffset`（默认 160pt），左右列起点一致。
- 首次进入前先准备布局：
  - `collectionView.isHidden = true`
  - `prepareReelStart()` 内完成 layout + offset
  - 完成后显示，避免首帧跳动
- `viewWillAppear` 里只执行一次准备。

## 瀑布流布局
- 自定义 `ReelMasonryLayout`，两列短列优先。
- 缓存基础 frame 与 `columnForItem`，应用 `frame.y -= offset` 实现 Reel。
- `contentHeight` = max(两列高度)。

## 数据与颜色
- item 高度数组循环生成，数量 120。
- 若 `contentHeight < viewHeight * 1.3`，重复追加（最多 20 次）。
- 左列暖色 palette，右列冷色 palette（通过 `columnIndex` 决定）。

## 配置默认值

`ReelConfig`：
- `countdown = 3.5`
- `reelSpeed = 60`
- `reelStartOffset = 160`
- `maxReelOffsetDelta = 0`（0 表示不限制错位增量）
- `alignDuration = 0.2`（保留字段）
- `minFillMultiplier = 1.3`
- `contentInset = (16,16,16,16)`
- `columnSpacing = 12`，`itemSpacing = 12`

## 文件清单
- `HomeViewController.swift`
- `ReelWaterfallViewController.swift`
- `ReelWaterfallView.swift`
- `ReelMasonryLayout.swift`
- `ReelCell.swift`
- `ReelItem.swift`
- `ReelConfig.swift`
- `SceneDelegate.swift`

输出：可运行 Demo，进入不跳动，触摸后不抬手即可滚动，Resume 从当前位置继续，切换无位移。
