import UIKit
import PromiseKit
import Foundation

class AssetListViewController: BaseViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var assetsTitleLabel: UILabel!
    @IBOutlet weak var qrButton: UIButton!
    @IBOutlet weak var createNewWalletView: CreateNewWalletView!
    @IBOutlet weak var liquidBasicsView: LiquidBasicsView!

    private var assets: [Asset] = []
    private var transactionToken: NSObjectProtocol?
    private var pinnedAssets: [String: UInt64] {
        get {
            var pinned = UserDefaults.standard.object(forKey: Constants.Keys.pinnedAssets) as? [String] ?? []
            pinned.insert(Liquid.shared.usdtId, at: 0)
            return pinned.reduce([String: UInt64]()) { (dict, asset) -> [String: UInt64] in
                var dict = dict
                dict[asset] = 0
                return dict
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 86
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorColor = .clear
        tableView.backgroundColor = .aquaBackgroundBlue
        tableView.backgroundView?.backgroundColor = .aquaBackgroundBlue
        let nib = UINib(nibName: "AssetListCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "AssetListCell")
        liquidBasicsView.round(radius: 24)
        qrButton.round(radius: 0.5 * qrButton.bounds.width)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        transactionToken = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "transaction"), object: nil, queue: .main, using: onNewTransaction)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configure()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let token = transactionToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func onNewTransaction(_ notification: Notification) {
        self.reloadData()
        self.showBackupIfNotified()
    }

    func configure() {
        createNewWalletView.delegate = self
        if hasWallet {
            qrButton.isHidden = false
            tableView.isHidden = false
            createNewWalletView.isHidden = true
            liquidBasicsView.isHidden = true
            reloadData()
            showBackupIfNeeded()
        } else {
            createNewWalletView.isHidden = false
            liquidBasicsView.isHidden = false
        }
    }

    func balancePromise(_ sharedNetwork: NetworkSession) -> Promise<[String: UInt64]> {
        return Promise<[String: UInt64]> { seal in
            seal.fulfill(sharedNetwork.balance ?? [:])
        }
    }

    func reloadData() {
        let bgq = DispatchQueue.global(qos: .background)
        firstly {
            return Guarantee()
        }.then(on: bgq) {
            when(fulfilled: self.balancePromise(Bitcoin.shared), self.balancePromise(Liquid.shared))
        }.done { bitcoin, liquid in
            let balance = bitcoin.merging(liquid) { (_, new) in new }
            self.assets = AquaService.assets(for: balance.merging(self.pinnedAssets) {(current, _) in current})
            self.tableView.reloadData()
        }.catch { _ in
            let alert = UIAlertController(title: NSLocalizedString("id_error", comment: ""), message: "Failure on fetch balance", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_retry", comment: ""), style: .default, handler: { _ in self.reloadData() }))
            self.present(alert, animated: true)
        }
    }

    @IBAction func qrCodeTapped(_ sender: Any) {
        performSegue(withIdentifier: "qrcode", sender: nil)
    }

    @IBAction func addAssetTapped(_ sender: Any) {
        performSegue(withIdentifier: "add_asset", sender: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let dest = segue.destination as? OnboardingLandingViewController {
            dest.presentationController?.delegate = self
        } else if let dest = segue.destination as? AssetDetailViewController {
            dest.asset = sender as? Asset
        } else if let dest = segue.destination as? AddAssetsViewController {
            dest.delegate = self
            dest.balance = assets.filter { $0.sats ?? 0 > 0 }
        }
    }
}

extension AssetListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView(frame: .zero)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return assets.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let asset = assets[indexPath.row]
        if let cell = tableView.dequeueReusableCell(withIdentifier: "AssetListCell") as? AssetListCell {
            cell.configure(with: asset)
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let asset = assets[indexPath.row]
        performSegue(withIdentifier: "asset_detail", sender: asset)
    }
}

extension AssetListViewController: CreateWalletDelegate {
    func didTapCreate() {
        showOnboarding(with: self)
    }

    func didTapRestore() {
        showRestore(with: self)
    }
}

extension AssetListViewController: UIAdaptivePresentationControllerDelegate {

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        configure()
    }
}

extension AssetListViewController: AssetsProtocol {

    func update() {
        reloadData()
    }
}
