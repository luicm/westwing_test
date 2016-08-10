
import Foundation
import UIKit
import PlaygroundSupport

enum ProductResult {
    case success([Product])
    case failure(Error)
}

enum APIError: Error {
    case emptyJSONData
    case invalidJSONData
}

struct Product {
    let campaignID: String
    let title: String
    let subtitle: String
    let description: String  
    let startTime: String
    let navigationURL: String
    let bannerURL: String
}

//********************************
//MARK:- Coordinator
//********************************

struct ProductListCoordinator {
    let jsonURL = "https://static.westwing.de/cms/dont-delete/programming_task/data.json"
    typealias productCompletion = (products: [Product]) -> Void
    
    func fetchProducts(completion: productCompletion) throws {
        let url = URL(string: jsonURL)
        let request = URLRequest(url: url!)
        let defaultSession = URLSession.shared
        let task = defaultSession.dataTask(with: request) { (data, response, error) in
            guard let jsonData = data else { return }
            do {
                let productResult = ProductListCoordinator.productsFromJSON(jsonData: jsonData)
                switch productResult {
                case .success(let result):
                    completion(products: result)
                case .failure(let error):
                    throw(error)
                }
            } catch let error as NSError{
                print("error: \(error))")
            }
        }
        task.resume()
    }
    
    static private func productsFromJSON(jsonData: Data) -> ProductResult {
        var products = [Product]()
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
            print(jsonObject)
            for product in jsonObject as! [AnyObject] {
                guard var id = product["id_campaign"] as? String,
                    productTitle = product["name"] as? String,
                    productSubtitle = product["subline"] as? String,
                    productDescription = product["description"] as? String,
                    productStartTime = product["start_time_formatted"] as? String,
                    productNavigationURL = product["navigation_url"] as? String,
                    productBannerURL = product["banner_url"] as? String
                else { 
                    return .failure(APIError.invalidJSONData)
                }
                
                let product = Product(campaignID: id, 
                                      title: productTitle.capitalized, 
                                      subtitle: productSubtitle, 
                                      description: productDescription, 
                                      startTime: productStartTime, 
                                      navigationURL: productNavigationURL, 
                                      bannerURL: productBannerURL)
                products.append(product)
            }
            return .success(products)
            
        } catch {
            return .failure(error)
        }
    }
}

//********************************
//MARK:- Presenter
//********************************

protocol ProductListPresentable {
    func productListDidUpdate(products:[Product])
}

class ProductListPresenter {
    private let coordinator = ProductListCoordinator()
    private let delegate: ProductListPresentable
    
    private(set) var products = [Product]() {
        didSet {
            DispatchQueue.main.async() {
                self.delegate.productListDidUpdate(products: self.products)
            }
        }
    }
    
    init(delegate: ProductListPresentable) {
        self.delegate = delegate
        do {
            try coordinator.fetchProducts(completion: { (fetchedProducts) in
                self.products = fetchedProducts
            })
        } catch {
            fatalError("\(error))")
        }
    }
    
    func product(forIndex index: Int) -> Product {
        return products[index]
    }
}

//********************************
//MARK:- ViewControllers & View
//********************************

class ProductListViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, ProductListPresentable {
    private let productCellIdentifier = "productCell"
    private var presenter: ProductListPresenter!
    private let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
    
    override init(collectionViewLayout layout: UICollectionViewLayout) {
        super.init(collectionViewLayout: layout)
        presenter = ProductListPresenter(delegate: self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.collectionView?.register(ProductCell.self, forCellWithReuseIdentifier: productCellIdentifier);
        self.collectionView?.backgroundColor = UIColor.white
        self.collectionView?.addSubview(activityIndicator)
        self.title = "Nice List"
        activityIndicator.hidesWhenStopped = true
        clearsSelectionOnViewWillAppear = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let activityNewFrame = CGRect(x: (self.collectionView?.contentSize.width)!/2 - activityIndicator.frame.width, y: 200, width: activityIndicator.frame.width, height: activityIndicator.frame.height)
        activityIndicator.frame = activityNewFrame
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let count = presenter.products.count
        if count == 0 {
            activityIndicator.startAnimating()
        }
        return count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: productCellIdentifier, for: indexPath as IndexPath) as! ProductCell
        let product = presenter.product(forIndex: indexPath.row)
        cell.title.text = product.title
        cell.subtitle.text = product.subtitle
        let url = URL(string: product.navigationURL)
        if let image = url?.cachedImage {
            cell.productImage.image = image
            cell.productImage.contentMode = .scaleAspectFill
        } else {
            cell.activityIndicator.startAnimating()
            url?.fetchImage { image in
                cell.productImage.image = image
                cell.activityIndicator.stopAnimating()
            }
        }
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! ProductCell
        cell.alpha = 0.8
        let product = presenter.product(forIndex: indexPath.row)
        let detailViewController = ProductDetailViewController()
        detailViewController.product = product
        self.show(detailViewController, sender: self)
    }
    
    // UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let itemWidth = ((self.collectionView?.contentSize.width)! / 2) - 30
        return CGSize(width: itemWidth, height: itemWidth)
    }
    
    // ProductListPresentable
    func productListDidUpdate(products: [Product]) {
        self.collectionView?.reloadData()
        activityIndicator.stopAnimating()
    }
}

class ProductCell: UICollectionViewCell {
    var productImage = UIImageView()
    var title = UILabel()
    var subtitle = UILabel()
    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
    
    override func prepareForReuse() {
        productImage.image = nil
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.layer.cornerRadius = 7
        self.layer.masksToBounds = true
        
        let gradientFrame = CGRect(x: 0, y: self.bounds.height/4, width: self.bounds.width, height: self.bounds.height/2)
        let gradientView = UIView(frame: gradientFrame)
        
        let backgroundGradient = Gradient().gradientLayer
        backgroundGradient.frame = gradientView.frame
        gradientView.layer.insertSublayer(backgroundGradient, at: 0)
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        productImage.translatesAutoresizingMaskIntoConstraints = false
        title.translatesAutoresizingMaskIntoConstraints = false
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        
        activityIndicator.hidesWhenStopped = true
        
        title.font = UIFont.boldSystemFont(ofSize: 17)
        title.numberOfLines = 0
        subtitle.font = UIFont.italicSystemFont(ofSize: 13)
        subtitle.numberOfLines = 0
        
        contentView.addSubview(activityIndicator)
        contentView.addSubview(productImage)
        contentView.addSubview(gradientView)
        contentView.addSubview(subtitle)
        contentView.addSubview(title)
        
        // Set activityIndicator AutolayoutConstrains
        let activityIndicatorVerticalConstraint = NSLayoutConstraint(item: activityIndicator, attribute: .centerY, relatedBy: .equal, toItem: contentView, attribute: .centerY, multiplier: 1, constant: 0)
        let activityIndicatorHorizontalConstraint = NSLayoutConstraint(item: activityIndicator, attribute: .centerX, relatedBy: .equal, toItem: contentView, attribute: .centerX, multiplier: 1, constant: 0)
        
        // Set image AutolayoutConstrains
        let imageTopConstraint = NSLayoutConstraint(item: productImage, attribute: .top, relatedBy: .equal, toItem: contentView, attribute: .top, multiplier: 1, constant: 0)
        let imageBottomConstraint = NSLayoutConstraint(item: productImage, attribute: .bottom, relatedBy: .equal, toItem: contentView, attribute: .bottom, multiplier: 1, constant: 0)
        let imageLeftConstraint = NSLayoutConstraint(item: productImage, attribute: .leading, relatedBy: .equal, toItem: contentView, attribute: .leading, multiplier: 1, constant: 0)
        let imageRightConstraint = NSLayoutConstraint(item: productImage, attribute: .trailing, relatedBy: .equal, toItem: contentView, attribute: .trailing, multiplier: 1, constant: 0)
        
        // Set title AutolayoutConstrains
        let titleLeftConstraint = NSLayoutConstraint(item: title, attribute: .leading, relatedBy: .equal, toItem: contentView, attribute: .leading, multiplier: 1, constant: 10)
        let titleRightConstraint = NSLayoutConstraint(item: title, attribute: .trailing, relatedBy: .equal, toItem: contentView, attribute: .trailing, multiplier: 1, constant: 10)
        
        // Set subtitle AutolayoutConstrains
        let subtitleLeftConstraint = NSLayoutConstraint(item: subtitle, attribute: .leading, relatedBy: .equal, toItem: contentView, attribute: .leading, multiplier: 1, constant: 10)
        let subtitleRightConstraint = NSLayoutConstraint(item: subtitle, attribute: .trailing, relatedBy: .equal, toItem: contentView, attribute: .trailing, multiplier: 1, constant: 10)
        let subtitleBottomConstraint = NSLayoutConstraint(item: subtitle, attribute: .bottom, relatedBy: .equal, toItem: contentView, attribute: .bottom, multiplier: 1, constant: -10)
        let subtitleTopConstraint = NSLayoutConstraint(item: subtitle, attribute: .top, relatedBy: .equal, toItem: title, attribute: .bottom, multiplier: 1, constant: 5)
        
        // Activate and add constrain to cell
        let cellConstraints = [activityIndicatorVerticalConstraint, activityIndicatorHorizontalConstraint, imageTopConstraint, imageLeftConstraint, imageRightConstraint, imageBottomConstraint, titleLeftConstraint, titleRightConstraint, subtitleTopConstraint, subtitleLeftConstraint, subtitleRightConstraint, subtitleBottomConstraint]
        
        NSLayoutConstraint.activate(cellConstraints)
        self.addConstraints(cellConstraints)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ProductDetailViewController: UIViewController {
    
    var product: Product?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        let detailView = ProductDetailView()
        detailView.detailProduct = product
        self.view = detailView
        
        self.title = product?.title
    }
}

class ProductDetailView: UIView {
    var detailProduct: Product? {
        didSet {
            configureView(product: detailProduct!)
        }
    }
    private let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.white
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureView(product: Product) {
        let scroll = UIScrollView()
        let containerView = UIView()
        let image = UIImageView()
        let title = UILabel()
        let subtitle = UILabel()
        let description = UILabel()
        let startDate = UILabel()
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        image.translatesAutoresizingMaskIntoConstraints = false
        title.translatesAutoresizingMaskIntoConstraints = false
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        description.translatesAutoresizingMaskIntoConstraints = false
        startDate.translatesAutoresizingMaskIntoConstraints = false
        
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()
        
        let url = URL(string: product.bannerURL)
        url?.fetchImage(completion: { (newImage) in
            image.contentMode = .scaleAspectFill
            image.image = newImage
            self.activityIndicator.stopAnimating()
        })
        
        image.layer.cornerRadius = 7
        image.clipsToBounds = true
        title.text = product.title
        title.font = UIFont.boldSystemFont(ofSize: 19)
        title.numberOfLines = 0
        title.backgroundColor = UIColor.white
        subtitle.text = product.subtitle
        subtitle.font = UIFont.italicSystemFont(ofSize: 14)
        subtitle.numberOfLines = 0
        startDate.text = product.startTime
        startDate.font = UIFont.boldSystemFont(ofSize: 13)
        description.text = product.description
        description.font = UIFont.systemFont(ofSize: 14)
        description.numberOfLines = 0
        
        scroll.addSubview(containerView)
        containerView.addSubview(activityIndicator)
        containerView.addSubview(image)
        containerView.addSubview(title)
        containerView.addSubview(subtitle)
        containerView.addSubview(description)
        containerView.addSubview(startDate)
        self.addSubview(scroll)
        
        // Set scroll AutoLayout
        let scrollTopConstraint = NSLayoutConstraint(item: scroll, attribute: .top, relatedBy: .equal, toItem: scroll.superview, attribute: .top, multiplier: 1, constant: 0)
        let scrollLeftConstraint = NSLayoutConstraint(item: scroll, attribute: .leading, relatedBy: .equal, toItem: scroll.superview, attribute: .leading, multiplier: 1, constant: 0)
        let scrollBottomConstraint = NSLayoutConstraint(item: scroll, attribute: .bottom, relatedBy: .equal, toItem: scroll.superview, attribute: .bottom, multiplier: 1, constant: 0)
        let scrollRightConstraint = NSLayoutConstraint(item: scroll, attribute: .trailing, relatedBy: .equal, toItem: scroll.superview, attribute: .trailing, multiplier: 1, constant: 0)
        
        // Set containerView AutoLayout
        let containerViewWidthConstraint = NSLayoutConstraint(item: containerView, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1, constant: 0)
        let containerViewTopConstraint = NSLayoutConstraint(item: containerView, attribute: .top, relatedBy: .equal, toItem: scroll, attribute: .top, multiplier: 1, constant: 0)
        let containerViewBottomConstraint = NSLayoutConstraint(item: containerView, attribute: .bottom, relatedBy: .equal, toItem: scroll, attribute: .bottom, multiplier: 1, constant: 0)
        let containerViewVerticalConstraint = NSLayoutConstraint(item: containerView, attribute: .centerX, relatedBy: .equal, toItem: scroll, attribute: .centerX, multiplier: 1, constant: 0)
        
        // Set activityIndicator AutolayoutConstrains
        let activityIndicatorVerticalConstraint = NSLayoutConstraint(item: activityIndicator, attribute: .centerY, relatedBy: .equal, toItem: image, attribute: .centerY, multiplier: 1, constant: 0)
        let activityIndicatorHorizontalConstraint = NSLayoutConstraint(item: activityIndicator, attribute: .centerX, relatedBy: .equal, toItem: image, attribute: .centerX, multiplier: 1, constant: 0)
        
        // Set image AutoLayout 
        let imageTopConstraint = NSLayoutConstraint(item: image, attribute: .top, relatedBy: .equal, toItem: containerView, attribute: .top, multiplier: 1, constant: 20)
        let imageVerticalConstraint = NSLayoutConstraint(item: image, attribute: .centerX, relatedBy: .equal, toItem: containerView, attribute: .centerX, multiplier: 1, constant: 0)
        let imageWidthConstraint = NSLayoutConstraint(item: image, attribute: .width, relatedBy: .equal, toItem: containerView, attribute: .width, multiplier: 0.9, constant: 0)
        let imageHeightConstraint = NSLayoutConstraint(item: image, attribute: .height, relatedBy: .equal, toItem: image, attribute: .width, multiplier: 1, constant: 0)
        
        //Set title AutoLayout
        let titleTopConstraint = NSLayoutConstraint(item: title, attribute: .top, relatedBy: .equal, toItem: image, attribute: .bottom, multiplier: 1, constant: 25)
        let titleLeftConstraint = NSLayoutConstraint(item: title, attribute: .leading, relatedBy: .equal, toItem: containerView, attribute: .leading, multiplier: 1, constant: 25)
        let titleRightConstraint = NSLayoutConstraint(item: title, attribute: .trailing, relatedBy: .equal, toItem: containerView, attribute: .trailing, multiplier: 1, constant: -25)
        
        // Set subtitle Autolayout
        let subtitleTopConstraint = NSLayoutConstraint(item: subtitle, attribute: .top, relatedBy: .equal, toItem: title, attribute: .bottom, multiplier: 1, constant: 5)
        let subtitleLeftConstraint = NSLayoutConstraint(item: subtitle, attribute: .leading, relatedBy: .equal, toItem: containerView, attribute: .leading, multiplier: 1, constant: 25)
        let subtitleRightConstraint = NSLayoutConstraint(item: subtitle, attribute: .trailing, relatedBy: .equal, toItem: containerView, attribute: .trailing, multiplier: 1, constant: -25)
        
        // Set startDate Autolayout
        let startDateTopConstraint = NSLayoutConstraint(item: startDate, attribute: .top, relatedBy: .equal, toItem: subtitle, attribute: .bottom, multiplier: 1, constant: 5)
        let startDateLeftConstraint = NSLayoutConstraint(item: startDate, attribute: .leading, relatedBy: .equal, toItem: containerView, attribute: .leading, multiplier: 1, constant: 25)
        let startDateRightConstraint = NSLayoutConstraint(item: subtitle, attribute: .trailing, relatedBy: .equal, toItem: containerView, attribute: .trailing, multiplier: 1, constant: -25)
        
        // Set description Autolayout
        let descriptionTopConstraint = NSLayoutConstraint(item: description, attribute: .top, relatedBy: .equal, toItem: startDate, attribute: .bottom, multiplier: 1, constant: 10)
        let descriptionLeftConstraint = NSLayoutConstraint(item: description, attribute: .leading, relatedBy: .equal, toItem: containerView, attribute: .leading, multiplier: 1, constant: 25)
        let descriptionRightConstraint = NSLayoutConstraint(item: description, attribute: .trailing, relatedBy: .equal, toItem: containerView, attribute: .trailing, multiplier: 1, constant: -25)
        let descriptionBottomConstraint = NSLayoutConstraint(item: description, attribute: .bottom, relatedBy: .equal, toItem: containerView, attribute: .bottom, multiplier: 1, constant: -15)
        
        // Activate and add constraints
        let detailConstraints = [scrollTopConstraint, scrollLeftConstraint, scrollRightConstraint, scrollBottomConstraint, containerViewTopConstraint, containerViewVerticalConstraint, containerViewBottomConstraint, containerViewWidthConstraint, imageTopConstraint, imageWidthConstraint, imageHeightConstraint, imageVerticalConstraint, activityIndicatorVerticalConstraint,activityIndicatorHorizontalConstraint, titleTopConstraint, titleLeftConstraint, titleRightConstraint, subtitleTopConstraint, subtitleLeftConstraint, subtitleRightConstraint, startDateTopConstraint, startDateLeftConstraint, startDateRightConstraint, descriptionTopConstraint, descriptionLeftConstraint, descriptionRightConstraint, descriptionBottomConstraint]
        
        NSLayoutConstraint.activate(detailConstraints)
        self.addConstraints(detailConstraints)
        
        self.updateConstraints()
    }
}

//********************************
//MARK:- Utilities
//********************************

class WestwingImageCache {
    static let sharedCache: NSCache<AnyObject, AnyObject> = {
        let cache = NSCache<AnyObject, AnyObject>()
        cache.name = "MyImageCache"
        cache.countLimit = 20 // Max 20 images in memory.
        cache.totalCostLimit = 10*1024*1024 // Max 10MB used.
        return cache
    }()
}


extension URL {
    typealias ImageCacheCompletion = (UIImage) -> Void
    
    var cachedImage: UIImage? {
        return WestwingImageCache.sharedCache.object(
            forKey: absoluteString) as? UIImage
    }
    
    func fetchImage(completion: ImageCacheCompletion) {
        let task = URLSession.shared.dataTask(with: self) {
            data, response, error in
            if error == nil {
                if let  data = data,
                    image = UIImage(data: data) {
                    WestwingImageCache.sharedCache.setObject(
                        image, 
                        forKey: self.absoluteString, 
                        cost: data.count)
                    DispatchQueue.main.async() {
                        completion(image)
                    }
                }
            }
        }
        task.resume()
    }
}

class Gradient {
    let colorTop = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.0).cgColor
    let colorBottom = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.8).cgColor
    
    let gradientLayer: CAGradientLayer
    
    init() {
        gradientLayer = CAGradientLayer()
        gradientLayer.colors = [ colorTop, colorBottom]
        gradientLayer.locations = [ 0.0, 1.0]
    }
}

//********************************
//MARK:- UI Setup
//********************************

var flowLayout = UICollectionViewFlowLayout();
flowLayout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
flowLayout.minimumLineSpacing = 20
flowLayout.minimumInteritemSpacing = 20
let productsViewController = ProductListViewController(collectionViewLayout: flowLayout)
let navigationController = UINavigationController(rootViewController: productsViewController)

PlaygroundPage.current.liveView = navigationController
//PlaygroundPage.current.needsIndefiniteExecution = true

