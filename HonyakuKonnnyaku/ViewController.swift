//
//  ViewController.swift
//  HonyakuKonnnyaku
//
//  Created by Paul McCartney on 2018/07/03.
//  Copyright © 2018年 Satsuki Hashiba. All rights reserved.
//

import UIKit
import ReactiveSwift
import ReactiveCocoa

class ViewController: UIViewController {
    @IBOutlet weak var streamButton: UIButton!
    @IBOutlet weak var originalTextView: UITextView!
    @IBOutlet weak var translatedTextView: UITextView!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    let viewModel = ViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        configure()
        bind()
    }
    
    func configure() {
        segmentedControl.removeAllSegments()
        viewModel.languageArray.enumerated().forEach { index, title in
            segmentedControl.insertSegment(withTitle: title, at: index, animated: false)
        }
        segmentedControl.selectedSegmentIndex = 0
        
    }
    
    func bind() {
        streamButton.reactive.controlEvents(.touchUpInside)
            .observeValues { [viewModel] _ in
                viewModel.tappedStreaming()
        }
        
        originalTextView.reactive.text <~ viewModel.originalText
        translatedTextView.reactive.text <~ viewModel.translatedText
        indicator.reactive.isHidden <~ viewModel.isTranslating.negate()
        streamButton.reactive.isEnabled <~ viewModel.isTranslating.negate()
        
        segmentedControl.reactive.controlEvents(.valueChanged)
            .observeValues { [viewModel] segmented in
                let selectedIndex = segmented.selectedSegmentIndex
                viewModel.changedSegmented(index: selectedIndex)
        }
        
        viewModel.isStreaming.filter { $0 == true }
            .startWithValues { [unowned self] _ in
                self.streamButton.setTitle("Stop streaming", for: .normal)
                self.originalTextView.text = ""
        }
        
        viewModel.isStreaming.filter { $0 == false }
            .startWithValues { [unowned self] _ in
                self.streamButton.setTitle("Start streaming", for: .normal)
        }
        
        viewModel.isTranslating.observe(on: UIScheduler())
            .startWithValues { [unowned self] isTranslating in
            isTranslating ? self.indicator.startAnimating() : self.indicator.stopAnimating()
        }
    }
}

