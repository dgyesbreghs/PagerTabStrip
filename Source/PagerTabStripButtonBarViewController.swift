//
//  PagerTabStripButtonBarViewController.swift
//  BoleroPhone
//
//  Created by Dylan Gyesbreghs on 21/08/2018.
//  Copyright © 2018 iCapps. All rights reserved.
//

import UIKit


class PagerTabStripButtonBarViewController: PagerTabStripViewController {

    // MARK: - Private Properties
    fileprivate var shouldUpdateButtonBarView: Bool = true
    fileprivate var collectionViewDidLoad: Bool = false

    fileprivate var cachedCellWidths: [CGFloat]?
    fileprivate lazy var buttonBarView: PagerTabStripButtonBarView = { [weak self] in
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        let frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 44)
        let barView = PagerTabStripButtonBarView(frame: frame,
                                                 collectionViewLayout: flowLayout)
        barView.autoresizingMask = [.flexibleWidth]
        barView.delegate = self
        barView.dataSource = self
        barView.scrollsToTop = false
        barView.showsHorizontalScrollIndicator = false
        return barView
    }()
    
    // MARK: - View Life Cycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        setupButtonBarView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        buttonBarView.layoutIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if isViewAppearing || isViewRotating {
            cachedCellWidths = calculateWidths()
            buttonBarView.collectionViewLayout.invalidateLayout()
            buttonBarView.move(toIndex: currentIndex, animated: false, swipeDirection: .none, pagerScroll: .scrollOnlyIfOutOfScreen)
            buttonBarView.selectItem(at: IndexPath(item: currentIndex, section: 0), animated: false, scrollPosition: UICollectionView.ScrollPosition.init(rawValue: 0))
        }
    }
    
    func reloadTabs() {
        buttonBarView.reloadData()
        cachedCellWidths = calculateWidths()
        buttonBarView.updateSelectedBarPosition(animated: true, swipeDirection: .none, pagerScroll: .yes)
    }
}

// MARK: - Setup Methods
fileprivate extension PagerTabStripButtonBarViewController {
    func setupButtonBarView() {
        var newContainerViewFrame = containerView.frame
        newContainerViewFrame.origin.y = 44
        newContainerViewFrame.size.height = containerView.frame.height - (44 - containerView.frame.origin.y)
        containerView.frame = newContainerViewFrame
        view.addSubview(buttonBarView)
    }
}

// MARK: - Private Methods
fileprivate extension PagerTabStripButtonBarViewController {
    func calculateWidths() -> [CGFloat] {
        guard let flowLayout = buttonBarView.collectionViewLayout as? UICollectionViewFlowLayout else { return [] }
        let numberOfCells = viewControllers.count
        var widths: [CGFloat] = []
        var collectionViewContentWidth: CGFloat = 0
        
        for viewController in viewControllers {
            guard let childTitle = viewController.childTitle else { continue }
            let width = minimumCellWidths(forTitle: childTitle)
            widths.append(width)
            collectionViewContentWidth += width
        }
        
        let cellSpacingTotal: CGFloat = CGFloat(numberOfCells - 1) * flowLayout.minimumLineSpacing
        collectionViewContentWidth += cellSpacingTotal
        
        let collectionViewAvailableVisibleWidth = buttonBarView.frame.width - flowLayout.sectionInset.left - flowLayout.sectionInset.right
        
        if collectionViewAvailableVisibleWidth < collectionViewContentWidth {
            return widths
        } else {
            let stretchedCellWidthIfAllEqual = (collectionViewAvailableVisibleWidth - cellSpacingTotal) / CGFloat(numberOfCells)
            let generalMinimumCellWidth = calculateStretchedCellWidths(withMinimumCellWidths: widths, suggestedStretchedCellWidth: stretchedCellWidthIfAllEqual, previousNumberOfLargeCells: 0)
            var stretchedCellWidths: [CGFloat] = []
            for minimumCellWidthValue in widths {
                let cellWidth = minimumCellWidthValue > generalMinimumCellWidth ? minimumCellWidthValue : generalMinimumCellWidth
                stretchedCellWidths.append(cellWidth)
            }
            return stretchedCellWidths
        }
    }
    
    func minimumCellWidths(forTitle title: String) -> CGFloat {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        let labelSize = label.intrinsicContentSize
        return labelSize.width + 40
    }
}

// MARK: - Public Methods
extension PagerTabStripButtonBarViewController {
    override func reloadPagerTabStripView() {
        super.reloadPagerTabStripView()
        if isViewLoaded {
            buttonBarView.reloadData()
            cachedCellWidths = calculateWidths()
            buttonBarView.move(toIndex: currentIndex, animated: false, swipeDirection: .none, pagerScroll: .yes)
        }
    }
    
    func calculateStretchedCellWidths(withMinimumCellWidths cellWidths: [CGFloat], suggestedStretchedCellWidth: CGFloat, previousNumberOfLargeCells: Int) -> CGFloat {
        var numberOfLargeCells: Int = 0
        var totalWidthOfLargeCells: CGFloat = 0
        
        for minimumCellWidthValue in cellWidths where minimumCellWidthValue > suggestedStretchedCellWidth {
            totalWidthOfLargeCells += minimumCellWidthValue
            numberOfLargeCells += 1
        }
        
        if numberOfLargeCells <= previousNumberOfLargeCells { return suggestedStretchedCellWidth }
        guard let flowLayout = buttonBarView.collectionViewLayout as? UICollectionViewFlowLayout else { return suggestedStretchedCellWidth }
        let collectionViewAvailiableWidth = buttonBarView.frame.width - flowLayout.sectionInset.left - flowLayout.sectionInset.right
        let numberOfCells = cellWidths.count
        let cellSpacingTotal = CGFloat(numberOfCells - 1) * flowLayout.minimumLineSpacing
        
        let numberOfSmallCells = numberOfCells - numberOfLargeCells
        let newSuggestedStretchedCellWidth = (collectionViewAvailiableWidth - totalWidthOfLargeCells - cellSpacingTotal) / CGFloat(numberOfSmallCells)
        return self.calculateStretchedCellWidths(withMinimumCellWidths: cellWidths, suggestedStretchedCellWidth: newSuggestedStretchedCellWidth, previousNumberOfLargeCells: numberOfLargeCells)
    }
}

// MARK: - UICollectionViewDataSource
extension PagerTabStripButtonBarViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewControllers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PagerTabStripButtonBarViewCell.reuseIdentifier,  // swiftlint:disable force_cast
                                                      for: indexPath) as! PagerTabStripButtonBarViewCell
        collectionViewDidLoad = true
        cell.setupCell(with: viewControllers[indexPath.row])
        return cell
    }
}

// MARK: - PagerTabStripDelegate
extension PagerTabStripButtonBarViewController: PagerTabStripDelegate {
    @objc func pagerTabStrip(controller: PagerTabStripViewController, fromIndex: Int, toIndex: Int) {
        if shouldUpdateButtonBarView {
            let direction: PagerTabStripSwipeDirection = toIndex < fromIndex ? .right : .left
            buttonBarView.move(toIndex: toIndex, animated: true, swipeDirection: direction, pagerScroll: .yes)
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension PagerTabStripButtonBarViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard
            let cachedCellWidths = cachedCellWidths,
            let width = cachedCellWidths[safe: indexPath.row] else { return .zero }
        return CGSize(width: width, height: collectionView.frame.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == currentIndex { return }
        buttonBarView.move(toIndex: indexPath.item, animated: true, swipeDirection: .none, pagerScroll: .yes)
        shouldUpdateButtonBarView = false
        moveToController(atIndex: indexPath.item)
    }
}

// MARK: - Override methods
extension PagerTabStripButtonBarViewController {
    override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        super.scrollViewDidEndScrollingAnimation(scrollView)
        if containerView == scrollView {
            shouldUpdateButtonBarView = true
        }
    }
}
