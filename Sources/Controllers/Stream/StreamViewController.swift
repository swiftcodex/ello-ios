//
//  StreamViewController.swift
//  Ello
//
//  Created by Sean Dougherty on 11/21/14.
//  Copyright (c) 2014 Ello. All rights reserved.
//

import Foundation
import UIKit


protocol WebLinkDelegate: NSObjectProtocol {
    func webLinkTapped(type: ElloURI, data: String)
}

protocol UserDelegate: NSObjectProtocol {
    func userTappedCell(cell: UICollectionViewCell)
}

protocol PostbarDelegate : NSObjectProtocol {
    func viewsButtonTapped(cell:UICollectionViewCell)
    func commentsButtonTapped(cell:StreamFooterCell, commentsButton: CommentButton)
    func lovesButtonTapped(cell:UICollectionViewCell)
    func repostButtonTapped(cell:UICollectionViewCell)
    func shareButtonTapped(cell:UICollectionViewCell)
    func flagPostButtonTapped(cell:UICollectionViewCell)
    func flagCommentButtonTapped(cell:UICollectionViewCell)
    func replyToPostButtonTapped(cell:UICollectionViewCell)
    func replyToCommentButtonTapped(cell:UICollectionViewCell)
}

protocol StreamImageCellDelegate : NSObjectProtocol {
    func imageTapped(imageView:UIImageView)
}

@objc protocol StreamScrollDelegate: NSObjectProtocol {
    func streamViewDidScroll(scrollView : UIScrollView)
    optional func streamViewWillBeginDragging(scrollView: UIScrollView)
    optional func streamViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool)
}

class StreamViewController: BaseElloViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    var pulsingCircle : PulsingCircle?
    var streamables:[Streamable]?
    var dataSource:StreamDataSource!
    var postbarController:PostbarController?
    var relationshipController: RelationshipController?
    var userListController: UserListController?
    var responseConfig: ResponseConfig?
    let streamService = StreamService()

    var streamKind:StreamKind = StreamKind.Friend {
        didSet {
            dataSource.streamKind = streamKind
            setupCollectionViewLayout()
        }
    }
    var imageViewerDelegate:StreamImageViewer?
    var updatedStreamImageCellHeightNotification:NotificationObserver?
    weak var postTappedDelegate : PostTappedDelegate?
    weak var userTappedDelegate : UserTappedDelegate?
    weak var streamScrollDelegate : StreamScrollDelegate?
    var notificationDelegate:NotificationDelegate? {
        get { return dataSource.notificationDelegate }
        set { dataSource.notificationDelegate = newValue }
    }

    var streamFilter:StreamDataSource.StreamFilter {
        get { return dataSource.streamFilter }
        set {
            dataSource.streamFilter = newValue
            collectionView.reloadData()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        initialSetup()
    }

    // If we ever create an init() method that doesn't use nib/storyboards,
    // we'll need to call this.  Called from awakeFromNib and init.
    private func initialSetup() {
        setupImageViewDelegate()
        setupDataSource()
        addNotificationObservers()
    }

    deinit {
        removeNotificationObservers()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupPulsingCircle()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let pulsingCircle = self.pulsingCircle {
            let (width, height) = (self.view.frame.size.width, self.view.frame.size.height)
            let center = CGPoint(x: width / 2, y: height / 2)
            pulsingCircle.center = center
        }
    }

    class func instantiateFromStoryboard() -> StreamViewController {
        return UIStoryboard.storyboardWithId(.Stream) as StreamViewController
    }

// MARK: Public Functions

    func doneLoading() {
        if let circle = pulsingCircle {
            circle.stopPulse() { finished in
                circle.removeFromSuperview()
            }
            pulsingCircle = nil
        }
    }

    func imageCellHeightUpdated(cell:StreamImageCell) {
        if let indexPath = collectionView.indexPathForCell(cell) {
            updateCellHeight(indexPath, height: cell.calculatedHeight)
        }
    }

    func addStreamCellItems(items: [StreamCellItem]) {
        dataSource.addStreamCellItems(items)
        collectionView.reloadData()
    }

    func addUnsizedCellItems(items:[StreamCellItem]) {
        dataSource.addUnsizedCellItems(items, startingIndexPath:nil) { indexPaths in
            self.collectionView.reloadData()
        }
    }

    func loadInitialPage() {
        streamService.loadStream(streamKind.endpoint,
            success: { (jsonables, responseConfig) in
                self.addUnsizedCellItems(StreamCellItemParser().parse(jsonables, streamKind: self.streamKind))
                self.responseConfig = responseConfig
                self.doneLoading()
            }, failure: { (error, statusCode) in
                println("failed to load \(self.streamKind.name) stream (reason: \(error))")
                self.doneLoading()
            }
        )
    }

// MARK: Private Functions

    private func setupPulsingCircle() {
        pulsingCircle = PulsingCircle.fill(self.view)
        view.addSubview(pulsingCircle!)
        pulsingCircle!.pulse()
    }

    private func addNotificationObservers() {
        updatedStreamImageCellHeightNotification = NotificationObserver(notification: updateStreamImageCellHeightNotification) { streamTextCell in
            self.imageCellHeightUpdated(streamTextCell)
        }
    }

    private func removeNotificationObservers() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        if let imageViewer = imageViewerDelegate {
            NSNotificationCenter.defaultCenter().removeObserver(imageViewer)
        }
    }

    private func updateCellHeight(indexPath:NSIndexPath, height:CGFloat) {
        collectionView.performBatchUpdates({
            self.dataSource.updateHeightForIndexPath(indexPath, height: height)
        }, completion: { (finished) in

        })
        collectionView.reloadItemsAtIndexPaths([indexPath])
    }

    private func setupCollectionView() {
        collectionView.delegate = self
        automaticallyAdjustsScrollViewInsets = false
        collectionView.alwaysBounceHorizontal = false
        collectionView.alwaysBounceVertical = true
        collectionView.directionalLockEnabled = true
        StreamCellType.registerAll(collectionView)
        setupCollectionViewLayout()
    }

    // this gets reset whenever the streamKind changes
    private func setupCollectionViewLayout() {
        let layout:StreamCollectionViewLayout = collectionView.collectionViewLayout as StreamCollectionViewLayout
        layout.columnCount = streamKind.columnCount
        layout.sectionInset = UIEdgeInsetsZero
        layout.minimumColumnSpacing = 12
        layout.minimumInteritemSpacing = 0
    }

    private func setupImageViewDelegate() {
        if imageViewerDelegate == nil {
            imageViewerDelegate = StreamImageViewer(controller:self)
        }
    }

    private func setupDataSource() {
        let webView = UIWebView(frame: self.view.bounds)
        let textSizeCalculator = StreamTextCellSizeCalculator(webView: UIWebView(frame: webView.frame))
        let notificationSizeCalculator = StreamNotificationCellSizeCalculator(webView: UIWebView(frame: webView.frame))

        dataSource = StreamDataSource(streamKind: streamKind,
            textSizeCalculator: textSizeCalculator,
            notificationSizeCalculator: notificationSizeCalculator)
        
        postbarController = PostbarController(collectionView: collectionView, dataSource: self.dataSource, presentingController: self)
        dataSource.postbarDelegate = postbarController

        relationshipController = RelationshipController(presentingController: self)
        dataSource.relationshipDelegate = relationshipController

        userListController = UserListController(presentingController: self)
        dataSource.userListDelegate = userListController

        if let imageViewer = imageViewerDelegate {
            dataSource.imageDelegate = imageViewer
        }
        dataSource.webLinkDelegate = self
        dataSource.userDelegate = self
        collectionView.dataSource = self.dataSource
    }

    private func presentProfile(username: String) {
        println("load username: \(username)")
    }

    private func showPostDetail(token: String) {
        println("show post detail: \(token)")
    }
}

// MARK: StreamViewController : WebLinkDelegate
extension StreamViewController : WebLinkDelegate {
    func webLinkTapped(type: ElloURI, data: String) {
        switch type {
        case .External: postNotification(externalWebNotification, data)
        case .Profile: presentProfile(data)
        case .Post: showPostDetail(data)
        }
    }
}

// MARK: StreamViewController : UserDelegate
extension StreamViewController : UserDelegate {

    func userTappedCell(cell: UICollectionViewCell) {
        if let indexPath = collectionView.indexPathForCell(cell) {
            if let user = dataSource.userForIndexPath(indexPath) {
                userTappedDelegate?.userTapped(user)
            }
        }
    }

}

// MARK: StreamViewController : UICollectionViewDelegate
extension StreamViewController : UICollectionViewDelegate {

    func collectionView(collectionView: UICollectionView,
        didSelectItemAtIndexPath indexPath: NSIndexPath) {
            if let post = dataSource.postForIndexPath(indexPath) {
                let items = dataSource.cellItemsForPost(post)
                postTappedDelegate?.postTapped(post, initialItems: items)
            }
    }

    func collectionView(collectionView: UICollectionView,
        shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
            return dataSource.streamCellItems[indexPath.item].type == StreamCellType.Header
    }
}

// MARK: StreamViewController : StreamCollectionViewLayoutDelegate
extension StreamViewController : StreamCollectionViewLayoutDelegate {

    func collectionView(collectionView: UICollectionView,layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
            return CGSizeMake(UIScreen.screenWidth(), dataSource.heightForIndexPath(indexPath, numberOfColumns:1))
    }

    func collectionView(collectionView: UICollectionView,layout collectionViewLayout: UICollectionViewLayout,
        groupForItemAtIndexPath indexPath: NSIndexPath) -> String {
            return dataSource.groupForIndexPath(indexPath)
    }

    func collectionView(collectionView: UICollectionView,layout collectionViewLayout: UICollectionViewLayout,
        heightForItemAtIndexPath indexPath: NSIndexPath, numberOfColumns: NSInteger) -> CGFloat {
            return dataSource.heightForIndexPath(indexPath, numberOfColumns:numberOfColumns)
    }

    func collectionView(collectionView: UICollectionView,layout collectionViewLayout: UICollectionViewLayout,
        maintainAspectRatioForItemAtIndexPath indexPath: NSIndexPath) -> Bool {
            return dataSource.maintainAspectRatioForItemAtIndexPath(indexPath)
    }

    func collectionView (collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
        isFullWidthAtIndexPath indexPath: NSIndexPath) -> Bool {
            return dataSource.isFullWidthAtIndexPath(indexPath)
    }
}

// MARK: StreamViewController : UIScrollViewDelegate
extension StreamViewController : UIScrollViewDelegate {

    func scrollViewDidScroll(scrollView : UIScrollView) {
        self.streamScrollDelegate?.streamViewDidScroll(scrollView)
        self.loadNextPage(scrollView)
    }

    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        if let delegate = self.streamScrollDelegate {
            delegate.streamViewWillBeginDragging?(scrollView)
        }
    }

    func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate: Bool) {
        if let delegate = self.streamScrollDelegate {
            delegate.streamViewDidEndDragging?(scrollView, willDecelerate: willDecelerate)
        }
    }

    private func loadNextPage(scrollView: UIScrollView) {
        if scrollView.contentOffset.y + self.view.frame.height + 300 > scrollView.contentSize.height {
            if self.responseConfig?.totalPagesRemaining == "0" { return }
            if let nextQueryItems = self.responseConfig?.nextQueryItems {
                let scrollAPI = ElloAPI.InfiniteScroll(path: streamKind.endpoint.path, queryItems: nextQueryItems)
                streamService.loadStream(scrollAPI,
                    success: {
                        (jsonables, responseConfig) in
                        self.addUnsizedCellItems(StreamCellItemParser().parse(jsonables, streamKind: self.streamKind))
                        self.responseConfig = responseConfig
                        self.doneLoading()
                    },
                    failure: { (error, statusCode) in
                        println("failed to load stream (reason: \(error))")
                        self.doneLoading()
                })
            }
        }
    }
}
