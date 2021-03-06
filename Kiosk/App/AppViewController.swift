import UIKit
import ARAnalytics

public class AppViewController: UIViewController, UINavigationControllerDelegate {
    var allowAnimations = true
    var auctionID = AppSetup.sharedState.auctionID

    @IBOutlet var countdownManager: ListingsCountdownManager!
    @IBOutlet public var offlineBlockingView: UIView!

    let reachability = ReachabilityManager()
    public var reachabilitySignal: RACSignal?

    let apiPinger = APIPingManager()
    var apiPingerSignal: RACSignal?


    dynamic var sale = Sale(id: "", name: "", isAuction: true, startDate: NSDate(), endDate: NSDate(), artworkCount: 0, state: "")

    public override func viewDidLoad() {
        super.viewDidLoad()

        let reachableSignal:RACSignal = reachabilitySignal ?? reachability.reachSignal
        let pingerSignal:RACSignal = apiPingerSignal ?? apiPinger.letOnlineSignal

        RAC(offlineBlockingView, "hidden") <~ RACSignal.combineLatest([reachableSignal, pingerSignal]).and()

        RAC(self, "sale") <~ auctionRequestSignal(auctionID)
        RAC(self, "countdownManager.sale") <~ RACObserve(self, "sale")

        for controller in childViewControllers {
            if let nav = controller as? UINavigationController {
                nav.delegate = self
            }
        }
    }

    @IBOutlet weak var registerToBidButton: ActionButton!
    public func navigationController(navigationController: UINavigationController, willShowViewController viewController: UIViewController, animated: Bool) {
        let show = (viewController as? SaleArtworkZoomViewController != nil)
        countdownManager.countdownContainerView.hidden = show
        registerToBidButton.hidden = show

    }
}

extension AppViewController {
    
    @IBAction func registerToBidButtonWasPressed(sender: AnyObject) {
        ARAnalytics.event("Register To Bid Tapped")

        let storyboard = UIStoryboard.fulfillment()
        let containerController = storyboard.instantiateInitialViewController() as FulfillmentContainerViewController
        containerController.allowAnimations = allowAnimations

        if let internalNav: FulfillmentNavigationController = containerController.internalNavigationController() {
            let registerVC = storyboard.viewControllerWithID(.RegisterAnAccount) as RegisterViewController
            registerVC.placingBid = false
            internalNav.auctionID = auctionID
            internalNav.viewControllers = [registerVC]
        }

        presentViewController(containerController, animated: false) {
            containerController.viewDidAppearAnimation(containerController.allowAnimations)
        }
    }

    @IBAction func longPressForAdmin(sender: UIGestureRecognizer) {
        if sender.state != .Began {
            return
        }
        
        let passwordVC = PasswordAlertViewController.alertView { [weak self] () -> () in
            self?.performSegue(.ShowAdminOptions)
            return
        }
        self.presentViewController(passwordVC, animated: true) {}
    }

    func auctionRequestSignal(auctionID: String) -> RACSignal {
        let auctionEndpoint: ArtsyAPI = ArtsyAPI.AuctionInfo(auctionID: auctionID)

        return XAppRequest(auctionEndpoint).filterSuccessfulStatusCodes().mapJSON().mapToObject(Sale.self).catch({ (error) -> RACSignal! in

            logger.error("Sale Artworks: Error handling thing: \(error.artsyServerError())")
            return RACSignal.empty()
        })
    }
}
