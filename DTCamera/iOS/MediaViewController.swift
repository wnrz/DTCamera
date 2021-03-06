//
//  MediaViewController.swift
//  DTCamera
//
//  Created by Dan Jiang on 2019/8/8.
//  Copyright © 2019 Dan Thought Studio. All rights reserved.
//

import UIKit
import CocoaLumberjack

protocol MediaTheme {
    var themeColor: UIColor { get }
    var previewThumbnailSelectedColor: UIColor { get }
}

extension MediaTheme {
    
    var themeColor: UIColor {
        return UIColor.blue
    }
    
    var previewThumbnailSelectedColor: UIColor {
        return UIColor.blue
    }
    
}

enum MediaSource {
    case library
    case capture
    case recording
    
    var title: String {
        switch self {
        case .library:
            return "相册"
        case .capture:
            return "拍照"
        case .recording:
            return "拍视频"
        }
    }
}

enum MediaType {
    case photo
    case video
    case all
}

enum CameraRatioMode {
    case r1to1
    case r3to4
    case r9to16
    
    var icon: UIImage {
        switch self {
        case .r1to1:
            return #imageLiteral(resourceName: "ratio_1_1")
        case .r3to4:
            return #imageLiteral(resourceName: "ratio_3_4")
        case .r9to16:
            return #imageLiteral(resourceName: "ratio_9_16")
        }
    }
    
    var ratio: CGFloat { // height : width
        switch self {
        case .r1to1:
            return 1.0
        case .r3to4:
            return 4.0 / 3.0
        case .r9to16:
            return 16.0 / 9.0
        }
    }
}

enum CameraPositionMode {
    case front
    case back
    
    var title: String {
        switch self {
        case .front:
            return "前置"
        case .back:
            return "后置"
        }
    }
}

struct MediaConfig {
    let videoURL: String
    let limitOfPhotos: Int
    let ratioMode: CameraRatioMode
    let positionMode: CameraPositionMode
    let minDuration: Int
    let maxDuration: Int
    let recordingFrameRate: Int = 24
    let recordingBitRate: Int = 1500000
    let audioSampleRate: Int = 44100
    let audioChannels: Int = 2
    let audioBitRate: Int = 64000
    let audioCodecName: String = "libfdk_aac"

    init(videoURL: String = "",
         limitOfPhotos: Int = 9,
         ratioMode: CameraRatioMode = .r3to4,
         positionMode: CameraPositionMode = .back,
         minDuration: Int = 5,
         maxDuration: Int = 60) {
        self.videoURL = videoURL
        self.limitOfPhotos = limitOfPhotos
        self.positionMode = positionMode
        self.ratioMode = ratioMode
        self.minDuration = minDuration
        self.maxDuration = maxDuration
    }
}

class MediaMode {
    var source: MediaSource // current choose tab
    let sources: [MediaSource] // all showed tabs
    let type: MediaType
    let config: MediaConfig
    
    init(sources: [MediaSource] = [.library, .capture], source: MediaSource = .capture,
         type: MediaType = .photo, config: MediaConfig) {
        self.sources = sources
        self.source = source
        self.type = type
        self.config = config
    }
}

enum SessionSetupResult {
    case success
    case notAuthorized
    case configurationFailed
}

protocol MediaViewControllerDelegate: class {
    func media(viewController: MediaViewController, didFinish photos: [UIImage])
    func media(viewController: MediaViewController, didFinish video: URL)
    func mediaDidDismiss(viewController: MediaViewController)
}

class MediaViewController: UIViewController {
    
    static func getMediaFileURL(name: String, ext: String, needRemove: Bool = true, needCreate: Bool = false) -> URL? {
        let documentsFolder = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let dirURL = URL(fileURLWithPath: documentsFolder).appendingPathComponent("DTCameraMedias", isDirectory: true)
        let fileURL = dirURL.appendingPathComponent(name).appendingPathExtension(ext)
        
        do {
            if !FileManager.default.fileExists(atPath: dirURL.path) {
                try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
            }
            if needRemove, FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            if needCreate, !FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil) {
                return nil
            }
        } catch {
            return nil
        }
        
        return fileURL
    }

    override var prefersStatusBarHidden: Bool { return true }

    struct DefaultTheme: MediaTheme {
        public init() {}
    }

    static var theme: MediaTheme = DefaultTheme()

    weak var delegate: MediaViewControllerDelegate?
    
    let mode: MediaMode

    private let photoLibraryVC: PhotoLibraryViewController
    private let cameraVC: CameraViewController
    
    private let buttons: [MediaSource: UIButton]
    private let indicator = UIView()
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(mode: MediaMode) {
        self.mode = mode
                
        var buttons: [MediaSource: UIButton] = [:]
        for source in mode.sources {
            buttons[source] = UIButton()
        }
        self.buttons = buttons
        
        self.photoLibraryVC = PhotoLibraryViewController(mode: mode)
        self.cameraVC = CameraViewController(mode: mode)
        
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupContentControllers()
        setupButtons()
    }
    
    func toggleButtons(isHidden: Bool) {
        for button in buttons.values {
            button.isHidden = isHidden
        }
        indicator.isHidden = isHidden
    }
    
    private func setupButtons() {
        indicator.backgroundColor = MediaViewController.theme.themeColor
        updateButtons()

        view.addSubview(indicator)
        for button in buttons.values {
            view.addSubview(button)
        }

        indicator.snp.makeConstraints { make in
            make.height.equalTo(2)
            make.width.equalTo(28)
            make.centerX.equalToSuperview()
            if #available(iOS 11, *) {
                make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
            } else {
                make.bottom.equalTo(self.bottomLayoutGuide.snp.top)
            }
        }
        if let currentIndex = mode.sources.firstIndex(of: mode.source) {
            for (index, source) in mode.sources.enumerated() {
                if let button = buttons[source] {
                    var offset = UIScreen.main.bounds.width > 320 ? 72 : 72 - 6
                    offset = (index - currentIndex) * offset
                    button.snp.makeConstraints { make in
                        make.centerX.equalToSuperview().offset(offset)
                        make.bottom.equalTo(indicator.snp.top).offset(-6)
                    }
                    button.addTarget(self, action: #selector(switchTo(_:)), for: .touchUpInside)
                }
            }
        }
    }
    
    private func updateButtons() {
        let otherTitleFont = UIFont.systemFont(ofSize: 16)
        let otherTitleColor = mode.source == .library ? UIColor(hex: "#4D4D4D")! : UIColor(hex: "#E6E6E6")!
        let currentTitleFont = UIFont.boldSystemFont(ofSize: 16)
        let currentTitleColor = MediaViewController.theme.themeColor
        for (source, button) in buttons {
            let buttonTitle = NSAttributedString(string: source.title,
                                                 attributes: [.font: mode.source == source ? currentTitleFont : otherTitleFont,
                                                              .foregroundColor: mode.source == source ? currentTitleColor : otherTitleColor])
            button.setAttributedTitle(buttonTitle, for: .normal)
            button.isUserInteractionEnabled = true            
        }
    }
    
    @objc private func switchTo(_ sender: UIButton) {
        var newSource: MediaSource = .library
        for (source, button) in buttons where sender == button {
            newSource = source
        }
        if mode.source == newSource {
            return
        }
        let oldSource = mode.source

        for button in buttons.values {
            button.isUserInteractionEnabled = false
        }
        
        var transitionContext: MediaSwitchTransitionContext?
        if newSource == .library {
            cameraVC.willMove(toParent: nil)
            addChild(photoLibraryVC)
            transitionContext = MediaSwitchTransitionContext(fromVC: cameraVC,
                                                             toVC: photoLibraryVC,
                                                             goRight: true)
        } else if oldSource == .library {
            cameraVC.source = newSource
            photoLibraryVC.willMove(toParent: nil)
            addChild(cameraVC)
            transitionContext = MediaSwitchTransitionContext(fromVC: photoLibraryVC,
                                                             toVC: cameraVC,
                                                             goRight: false)
        }
        if let transitionContext = transitionContext {
            transitionContext.completionBlock = { [weak self] _ in
                guard let self = self else { return }
                if newSource == .library {
                    self.cameraVC.removeFromParent()
                    self.photoLibraryVC.didMove(toParent: self)
                } else if oldSource == .library {
                    self.photoLibraryVC.removeFromParent()
                    self.cameraVC.didMove(toParent: self)
                }
            }
            let animator = MediaSwitchAnimator()
            animator.animateTransition(using: transitionContext)
        } else {
            cameraVC.source = newSource
        }
        
        if let newIndex = mode.sources.firstIndex(of: newSource) {
            for (index, source) in mode.sources.enumerated() {
                if let button = buttons[source] {
                    var offset = UIScreen.main.bounds.width > 320 ? 72 : 72 - 6
                    offset = (index - newIndex) * offset
                    button.snp.updateConstraints { make in
                        make.centerX.equalToSuperview().offset(offset)
                    }
                }
            }
        }
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut], animations: {
            self.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            self?.mode.source = newSource
            self?.updateButtons()
        })
    }

    private func setupContentControllers() {
        if mode.source == .library {
            displayContentController(photoLibraryVC)
        } else {
            displayContentController(cameraVC)
        }
    }
    
    private func displayContentController(_ content: UIViewController) {
        addChild(content)
        view.addSubview(content.view)
        content.didMove(toParent: self)
    }
    
}

class MediaSwitchAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView

        guard let fromVC = transitionContext.viewController(forKey: .from),
            let toVC = transitionContext.viewController(forKey: .to),
            let fromView = fromVC.view,
            let toView = toVC.view else {
                DDLogWarn("!!! Error: media switch animation is not allowed !!!")
                return
        }
        
        containerView.insertSubview(toView, at: 0)
        toView.frame = transitionContext.initialFrame(for: toVC)
        
        let fromVCFinalFrame = transitionContext.finalFrame(for: fromVC)
        let toVCFinalFrame = transitionContext.finalFrame(for: toVC)

        let duration = transitionDuration(using: transitionContext)
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut], animations: {
            fromView.frame = fromVCFinalFrame
            toView.frame = toVCFinalFrame
        }, completion: { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
    
}

class MediaSwitchTransitionContext: NSObject, UIViewControllerContextTransitioning {
    
    private let inViewControllers: [UITransitionContextViewControllerKey: UIViewController]
    private let inDisappearingFromRect: CGRect
    private let inDisappearingToRect: CGRect
    private let inAppearingFromRect: CGRect
    private let inAppearingToRect: CGRect
    
    init(fromVC: UIViewController, toVC: UIViewController, goRight: Bool) {
        inViewControllers = [.from: fromVC, .to: toVC]
        containerView = fromVC.view.superview ?? UIView()
        let containerViewWidth = containerView.bounds.size.width
        let travelDistance = goRight ? containerViewWidth : -containerViewWidth
        inDisappearingFromRect = containerView.bounds
        inDisappearingToRect = containerView.bounds.offsetBy(dx: travelDistance, dy: 0)
        inAppearingToRect = containerView.bounds
        inAppearingFromRect = containerView.bounds.offsetBy(dx: -travelDistance, dy: 0)
        isAnimated = true
        isInteractive = false
        transitionWasCancelled = false
        presentationStyle = .custom
        targetTransform = .identity
    }
    
    var completionBlock: ((_ didComplete: Bool) -> Void)?
    
    var containerView: UIView
    
    var isAnimated: Bool
    
    var isInteractive: Bool
    
    var transitionWasCancelled: Bool
    
    var presentationStyle: UIModalPresentationStyle
    
    func updateInteractiveTransition(_ percentComplete: CGFloat) {}
    
    func finishInteractiveTransition() {}
    
    func cancelInteractiveTransition() {}
    
    func pauseInteractiveTransition() {}
    
    func completeTransition(_ didComplete: Bool) {
        if let completionBlock = completionBlock {
            completionBlock(didComplete)
        }
    }
    
    func viewController(forKey key: UITransitionContextViewControllerKey) -> UIViewController? {
        return inViewControllers[key]
    }
    
    func view(forKey key: UITransitionContextViewKey) -> UIView? {
        return nil
    }
    
    var targetTransform: CGAffineTransform
    
    func initialFrame(for initialVC: UIViewController) -> CGRect {
        if initialVC == viewController(forKey: .from) {
            return inDisappearingFromRect
        } else {
            return inAppearingFromRect
        }
    }
    
    func finalFrame(for finalVC: UIViewController) -> CGRect {
        if finalVC == viewController(forKey: .from) {
            return inDisappearingToRect
        } else {
            return inAppearingToRect
        }
    }
    
}
