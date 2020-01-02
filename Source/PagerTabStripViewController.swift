//
//  PagerTabStripViewController.swift
//  BoleroPhone
//
//  Created by Dylan Gyesbreghs on 20/08/2018.
//  Copyright © 2018 iCapps. All rights reserved.
//

import UIKit

typealias PagerTabStripChildViewController = UIViewController & PagerTabStripChild

protocol PagerTabStripChild {
    var childTitle: String? { get }
}

protocol PagerTabStripDelegate: class {
    func pagerTabStrip(controller: PagerTabStripViewController, fromIndex: Int, toIndex: Int)
}

protocol PagerTabStripDataSource: class {
    func pagerTabStripViewController(for controller: PagerTabStripViewController) -> [PagerTabStripChildViewController]
}

class PagerTabStripViewController: UIViewController {

    // MARK: - Public Properties
    public weak var delegate: PagerTabStripDelegate?
    public weak var dataSource: PagerTabStripDataSource?
    
    public fileprivate(set) var currentIndex: Int = 0
    public fileprivate(set) var preCurrentIndex: Int = 0
    public fileprivate(set) var isViewRotating: Bool = false
    public fileprivate(set) var isViewAppearing: Bool = false
    public fileprivate(set) var viewControllers: [PagerTabStripChildViewController] = []
    public fileprivate(set) lazy var containerView: UIScrollView = { [weak self] in
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height))
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.bounces = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.scrollsToTop = false
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isPagingEnabled = true
        scrollView.delaysContentTouches = false
        return scrollView
    }()
    
    public var pageWidth: CGFloat {
        return containerView.bounds.width
    }
    
    public var scrollPercentage: CGFloat {
        if swipeDirection != .right {
            let module = fmod(containerView.contentOffset.x, pageWidth)
            return module == 0.0 ? 1.0 : module / pageWidth
        }
        return 1.0 - fmod(containerView.contentOffset.x >= 0 ? containerView.contentOffset.x : pageWidth + containerView.contentOffset.x, pageWidth) / pageWidth
    }
    
    public var swipeDirection: PagerTabStripSwipeDirection {
        if containerView.contentOffset.x > lastContentOffset {
            return .left
        } else if containerView.contentOffset.x < lastContentOffset {
            return .right
        }
        return .none
    }
    
    // MARK: - Private Properties
    fileprivate var pagerTabStripChildViewControllersForScrolling: [PagerTabStripChildViewController]?
    fileprivate var lastPageNumber: Int = 0
    fileprivate var lastContentOffset: CGFloat = 0.0
    fileprivate var pageBeforeRotate: Int = 0
    fileprivate var lastSize: CGSize = CGSize(width: 0, height: 0)
    
    // MARK: - View Life Cycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupContainerView()
        reloadViewControllers()
        setupChildViewController()
        updateContent()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isViewAppearing = true
        viewControllers.forEach { $0.beginAppearanceTransition(false, animated: animated) }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isViewAppearing = false
        viewControllers.forEach { $0.endAppearanceTransition() }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewControllers.forEach { $0.beginAppearanceTransition(false, animated: animated) }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isViewAppearing = false
        viewControllers.forEach { $0.endAppearanceTransition() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateIfNeeded()
    }
    
    // MARK: - Override Properties
    override var shouldAutomaticallyForwardAppearanceMethods: Bool {
        return false
    }
    
    // MARK: - Orientation
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        isViewRotating = true
        pageBeforeRotate = currentIndex
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let welf = self else { return }
            welf.isViewRotating = false
            welf.currentIndex = welf.pageBeforeRotate
            welf.preCurrentIndex = welf.currentIndex
            welf.updateIfNeeded()
        }
    }
}

// MARK: - Setup Methods
fileprivate extension PagerTabStripViewController {
    func setupContainerView() {
        containerView.delegate = self
        if containerView.superview == nil {
            view.addSubview(containerView)
        }
    }
    
    func setupChildViewController() {
        let childViewController = viewControllers[currentIndex]
        childViewController.willMove(toParent: self)
        addChild(childViewController)
        childViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(childViewController.view)
        childViewController.beginAppearanceTransition(true, animated: true)
        childViewController.didMove(toParent: self)
    }
}

// MARK: - Public Methods
extension PagerTabStripViewController {
    func moveToController(atIndex index: Int, animated: Bool = true) {
        if animated && (abs(currentIndex - index) >= 1) {
            var viewControllers = self.viewControllers
            let currentChildViewController = self.viewControllers[index]
            
            let fromindex = currentIndex < index ? index - 1 : index + 1
            let fromChildViewController = self.viewControllers[fromindex]
            
            viewControllers.insert(fromChildViewController, at: currentIndex)
            viewControllers.insert(currentChildViewController, at: fromindex)
            
            pagerTabStripChildViewControllersForScrolling = viewControllers
            
            let contentOffset = CGPoint(x: pageOffset(forChildAtIndex: fromindex), y: 0)
            containerView.setContentOffset(contentOffset, animated: true)
        }
        let view = navigationController?.view ?? self.view
        view?.isUserInteractionEnabled = !animated
        let contentOffset = CGPoint(x: pageOffset(forChildAtIndex: index), y: 0)
        containerView.setContentOffset(contentOffset, animated: animated)
    }
    
    func updateIfNeeded() {
        if isViewLoaded && !lastSize.equalTo(containerView.bounds.size) {
            updateContent()
        }
    }

    func canMove(toIndex index: Int) -> Bool {
        return (currentIndex != index) && (viewControllers.count > index)
    }

    func pageOffset(forChildAtIndex index: Int) -> CGFloat {
        return CGFloat(index) * pageWidth
    }

    func offset(forChildAtIndex index: Int) -> CGFloat {
        return (CGFloat(index) * pageWidth) + ((pageWidth - view.bounds.width) * 0.5)
    }

    func offset(forChildViewController viewController: PagerTabStripChildViewController) -> CGFloat {
        guard let index = viewControllers.firstIndex(where: { $0 == viewController }) else { return 0.0 }
        return offset(forChildAtIndex: index)
    }

    func page(forContentOffset contentOffset: CGFloat) -> Int {
        let vPage = virtualPage(forContentOffset: contentOffset)
        return page(forVirtualPage: vPage)
    }

    func virtualPage(forContentOffset contentOffset: CGFloat) -> Int {
        return Int(((contentOffset + 1.5 * pageWidth) / pageWidth) - 1)
    }

    func page(forVirtualPage virtualPage: Int) -> Int {
        if virtualPage <= 0 { return 0 }
        if virtualPage > (viewControllers.count - 1) { return viewControllers.count - 1 }
        return virtualPage
    }

    func updateContent() {
        if lastSize.width != containerView.bounds.width {
            lastSize = containerView.bounds.size
            containerView.contentOffset = CGPoint(x: pageOffset(forChildAtIndex: currentIndex), y: 0)
        }
        lastSize = containerView.bounds.size

        let viewControllers = pagerTabStripChildViewControllersForScrolling ?? self.viewControllers
        containerView.contentSize = CGSize(width: containerView.bounds.width * CGFloat(viewControllers.count), height: containerView.contentSize.height)
        
        for (index, childViewController) in viewControllers.enumerated() {
            let pageOffsetForChild = pageOffset(forChildAtIndex: index)
            if abs(containerView.contentOffset.x - pageOffsetForChild) < containerView.bounds.width {
                if childViewController.parent != nil {
                    childViewController.view.frame = CGRect(x: pageOffset(forChildAtIndex: index), y: 0, width: view.bounds.width, height: containerView.bounds.height)
                    childViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                } else {
                    childViewController.beginAppearanceTransition(true, animated: true)
                    childViewController.willMove(toParent: self)
                    addChild(childViewController)
                    childViewController.view.frame = CGRect(x: pageOffset(forChildAtIndex: index), y: 0, width: view.bounds.width, height: containerView.bounds.height)
                    childViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    containerView.addSubview(childViewController.view)
                    childViewController.didMove(toParent: self)
                    childViewController.endAppearanceTransition()
                }
            } else {
                if childViewController.parent != nil {
                    childViewController.beginAppearanceTransition(false, animated: false)
                    childViewController.willMove(toParent: nil)
                    childViewController.view.removeFromSuperview()
                    childViewController.removeFromParent()
                    childViewController.endAppearanceTransition()
                }
            }
        }
    }

    @objc func reloadPagerTabStripView() {
        if !isViewLoaded { return }
        
        for viewController in viewControllers where parent != nil {
            viewController.beginAppearanceTransition(false, animated: false)
            viewController.willMove(toParent: nil)
            viewController.view.removeFromSuperview()
            viewController.removeFromParent()
            viewController.endAppearanceTransition()
        }
        reloadViewControllers()
        containerView.contentSize = CGSize(width: containerView.bounds.width * CGFloat(viewControllers.count), height: containerView.bounds.height)
        if currentIndex >= viewControllers.count {
            currentIndex = viewControllers.count - 1
        }
        preCurrentIndex = currentIndex
        containerView.contentOffset = CGPoint(x: pageOffset(forChildAtIndex: currentIndex), y: 0)
        updateContent()
    }
    
    func pagerTapStripMoved(fromIndex: Int, toIndex: Int) {
        
    }
}

// MARK: - Private Methods
extension PagerTabStripViewController {
    func reloadViewControllers() {
        guard let dataSource = dataSource else { return }
        viewControllers = dataSource.pagerTabStripViewController(for: self)
        assert(viewControllers.count > 0, "pagerTabStripViewControllersFor: should provide at least one child viewcontroller")
    }
}

// MARK: - UIScrollViewDelegate
extension PagerTabStripViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if containerView == scrollView {
            updateContent()
            lastContentOffset = scrollView.contentOffset.x
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if containerView == scrollView {
            self.lastPageNumber = page(forContentOffset: scrollView.contentOffset.x)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if containerView == scrollView {
            let oldCurrentIndex = currentIndex
            let vPage = virtualPage(forContentOffset: containerView.contentOffset.x)
            let newCurrentIndex = page(forVirtualPage: vPage)
            currentIndex = newCurrentIndex
            preCurrentIndex = currentIndex
            
            if let delegate = delegate {
                delegate.pagerTabStrip(controller: self, fromIndex: min(oldCurrentIndex, viewControllers.count - 1), toIndex: newCurrentIndex)
            }
        }
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if containerView == scrollView {
            pagerTabStripChildViewControllersForScrolling = nil
            let view = navigationController?.view ?? self.view
            view?.isUserInteractionEnabled = true
            updateContent()
            
            let oldCurrentIndex = currentIndex
            let vPage = virtualPage(forContentOffset: containerView.contentOffset.x)
            let newCurrentIndex = page(forVirtualPage: vPage)
            currentIndex = newCurrentIndex
            preCurrentIndex = currentIndex
            
            pagerTapStripMoved(fromIndex: min(oldCurrentIndex, viewControllers.count - 1), toIndex: newCurrentIndex)
            if let delegate = delegate {
                delegate.pagerTabStrip(controller: self, fromIndex: min(oldCurrentIndex, viewControllers.count - 1), toIndex: newCurrentIndex)
            }
        }
    }
}
