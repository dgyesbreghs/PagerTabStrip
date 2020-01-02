//
//  PagerTabStripButtonBarViewCell.swift
//  BoleroPhone
//
//  Created by Dylan Gyesbreghs on 20/08/2018.
//  Copyright © 2018 iCapps. All rights reserved.
//

import UIKit

class PagerTabStripButtonBarViewCell: UICollectionViewCell {

    // MARK: - Outlet Properties
    @IBOutlet weak var label: UILabel?
    
    // MARK: - Memory Management
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        isAccessibilityElement = true
    }
}

// MARK: - Public Methods
extension PagerTabStripButtonBarViewCell {
    public func setupCell(with child: PagerTabStripChild) {
        label?.text = child.childTitle
        accessibilityLabel = child.childTitle
    }
}
