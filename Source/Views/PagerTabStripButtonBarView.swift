//
//  PagerTabStripButtonBarView.swift
//  BoleroPhone
//
//  Created by Dylan Gyesbreghs on 20/08/2018.
//  Copyright © 2018 iCapps. All rights reserved.
//

import UIKit

enum PagerTabStripButtonBarViewPagerScroll {
    case no
    case yes
    case scrollOnlyIfOutOfScreen
}

enum PagerTabStripButtonBarViewSelectedBarAlignment {
    case left
    case center
    case right
    case progressive
}

enum PagerTabStripButtonBarViewSelectedBarVerticalAlignment {
    case top
    case middle
    case bottom
}

class PagerTabStripButtonBarView: UICollectionView {
    
    // MARK: - Public Properties
    public var selectedIndex: Int = 0
    public var selectedBarAlignment: PagerTabStripButtonBarViewSelectedBarAlignment = .center
    public var selectedBarVerticalAlignment: PagerTabStripButtonBarViewSelectedBarVerticalAlignment = .bottom
    public lazy var selectedBar: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: frame.height - selectedBarHeight, width: 0, height: selectedBarHeight))
        view.layer.zPosition = 9999
        view.backgroundColor = .white
        return view
    }()

    // MARK: - Private Properties
    fileprivate var selectedBarHeight: CGFloat = 4.0 {
        didSet {
            updateSelectedBarYPosition()
        }
    }

    // MARK: - Memory Management
    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
 
    // MARK: - View Life Cycle
    override func layoutSubviews() {
        super.layoutSubviews()
        updateSelectedBarYPosition()
    }
}

// MARK: - Setup Methods
fileprivate extension PagerTabStripButtonBarView {
    func setupView() {
        addSubview(selectedBar)
        
        // Register Nib
        register(UINib(nibName: PagerTabStripButtonBarViewCell.reuseIdentifier),
                 forCellWithReuseIdentifier: PagerTabStripButtonBarViewCell.reuseIdentifier)
    }
}

// MARK: - Public Methods
extension PagerTabStripButtonBarView {
    func move(toIndex: Int, animated: Bool, swipeDirection: PagerTabStripSwipeDirection, pagerScroll: PagerTabStripButtonBarViewPagerScroll) {
        selectedIndex = toIndex
        updateSelectedBarPosition(animated: animated, swipeDirection: swipeDirection, pagerScroll: pagerScroll)
    }
    
    func move(fromIndex: Int, toIndex: Int, animated: Bool, progressPercentage: CGFloat, pagerScroll: PagerTabStripButtonBarViewPagerScroll) {
        selectedIndex = progressPercentage > 0.5 ? toIndex : fromIndex
        
        var toFrame: CGRect = .zero
        guard let fromFrame = layoutAttributesForItem(at: IndexPath(item: fromIndex, section: 0))?.frame, let dataSource = dataSource else { return }
        let numberOfItems = dataSource.collectionView(self, numberOfItemsInSection: 0)
        
        if toIndex < 0 || toIndex > numberOfItems - 1 {
            var cellAttributes = layoutAttributesForItem(at: IndexPath(item: 0, section: 0))
            if toIndex >= 0 {
                cellAttributes = layoutAttributesForItem(at: IndexPath(item: numberOfItems - 1, section: 0))
            }
            guard let cellAttribute = cellAttributes else { return }
            toFrame = cellAttribute.frame.offsetBy(dx: cellAttribute.frame.size.width, dy: 0)
        } else {
            guard let cellAttribute = layoutAttributesForItem(at: IndexPath(item: toIndex, section: 0)) else { return }
            toFrame = cellAttribute.frame
        }
        
        var targetFrame = fromFrame
        targetFrame.size.height = selectedBar.frame.height
        targetFrame.size.width += (toFrame.width - fromFrame.width) * progressPercentage
        targetFrame.origin.x += (toFrame.origin.x - fromFrame.origin.x) * progressPercentage

        selectedBar.frame = CGRect(x: targetFrame.origin.x, y: selectedBar.frame.origin.y, width: targetFrame.size.width, height: selectedBar.frame.size.height)

        var targetContentOffset: CGFloat = 0.0
        if contentSize.width > frame.size.width {
            let toContentOffset = contentOffset(forCellWithFrame: toFrame, index: toIndex)
            let fromContentOffset = contentOffset(forCellWithFrame: fromFrame, index: fromIndex)
            targetContentOffset = fromContentOffset + ((toContentOffset - fromContentOffset) * progressPercentage)
        }
        setContentOffset(CGPoint(x: targetContentOffset, y: 0), animated: false)
    }
    
    func updateSelectedBarPosition(animated: Bool, swipeDirection: PagerTabStripSwipeDirection, pagerScroll: PagerTabStripButtonBarViewPagerScroll) {
        var selectedBarFrame = selectedBar.frame
        
        let selectedCellIndexPath = IndexPath(item: selectedIndex, section: 0)
        guard let layoutAttributes = layoutAttributesForItem(at: selectedCellIndexPath) else { return }
        let selectedCellFrame = layoutAttributes.frame

        updateContentOffset(animated: animated, pagerScroll: pagerScroll, toFrame: selectedCellFrame, toIndex: selectedCellIndexPath.row)
        selectedBarFrame.size.width = selectedCellFrame.width
        selectedBarFrame.origin.x = selectedCellFrame.origin.x

        if animated {
            UIView.animate(withDuration: 0.3) { [weak self] in self?.selectedBar.frame = selectedBarFrame }
        } else {
            self.selectedBar.frame = selectedBarFrame
        }
    }
}

// MARK: - Private Methods
fileprivate extension PagerTabStripButtonBarView {
    func updateContentOffset(animated: Bool, pagerScroll: PagerTabStripButtonBarViewPagerScroll, toFrame: CGRect, toIndex: Int) {
        scrollToItem(at: IndexPath(row: toIndex, section: 0), at: .centeredHorizontally, animated: true)
    }
    
    func contentOffset(forCellWithFrame frame: CGRect, index: Int) -> CGFloat {
        guard let collectionViewFlowLayout = self.collectionViewLayout as? UICollectionViewFlowLayout, let dataSource = dataSource else {
            return 0
        }
        let sectionInset = collectionViewFlowLayout.sectionInset
        var alignmentOffset: CGFloat = 0.0
        
        switch selectedBarAlignment {
        case .left:
            alignmentOffset = sectionInset.left
        case .right:
            alignmentOffset = self.frame.width - sectionInset.right - frame.width
        case .center:
            alignmentOffset = (self.frame.size.width - frame.size.width) * 0.5
        case .progressive:
            let cellHalfWidth: CGFloat = frame.size.width * 0.5
            let leftAlignmentOffset: CGFloat = sectionInset.left + cellHalfWidth
            let rightAlignmentOffset: CGFloat = self.frame.size.width - sectionInset.right - cellHalfWidth
            let numerOfItems = dataSource.collectionView(self, numberOfItemsInSection: 0)
            let progress: CGFloat = CGFloat(index / (numerOfItems - 1))
            alignmentOffset = leftAlignmentOffset + (rightAlignmentOffset - leftAlignmentOffset) * progress - cellHalfWidth
        }
        
        var contentOffset = frame.origin.x - alignmentOffset
        contentOffset = max(0, contentOffset)
        contentOffset = min(contentSize.width - frame.size.width, contentOffset)
        return contentOffset
    }
    
    func updateSelectedBarYPosition() {
        var selectedBarFrame = selectedBar.frame
        
        switch selectedBarVerticalAlignment {
        case .top:
            selectedBarFrame.origin.y = 0
        case .middle:
            selectedBarFrame.origin.y = (frame.size.height - selectedBarHeight) / 2
        case .bottom:
            selectedBarFrame.origin.y = (frame.size.height - selectedBarHeight)
        }
        
        selectedBarFrame.size.height = selectedBarHeight
        selectedBar.frame = selectedBarFrame
    }
}
