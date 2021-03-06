import UIKit

class AssetInfoCell: UITableViewCell {

    @IBOutlet weak var infoTitle: UILabel!
    @IBOutlet weak var infoText: UILabel!

    func setup(title: String, text: String) {
        backgroundColor = .aquaBackgroundBlue
        infoTitle.text = title
        infoText.text = text
        infoTitle.textColor = .paleLilac
        selectionStyle = .none
    }

    func setup(title: String) {
        setup(title: title, text: "")
    }
}
