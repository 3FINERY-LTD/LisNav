import UIKit
import MapKit

class Station: NSObject, MKAnnotation {
  var title: String?
  var subtitle: String?
  var latitude: Double
  var longitude:Double

  var coordinate: CLLocationCoordinate2D {
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  init(latitude: Double, longitude: Double) {
    self.latitude = latitude
    self.longitude = longitude
  }
}

class MapViewController: UIViewController {
  @IBOutlet weak var mapView: MKMapView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    guard let path = Bundle.main.path(forResource: "dataset", ofType: "plist") else {return}
    
    let url = URL(fileURLWithPath: path)
    let data = try! Data(contentsOf: url)

    let annotations = getMapAnnotations()
    mapView.addAnnotations(annotations)
    mapView.userTrackingMode = .follow

    NotificationCenter.default.addObserver(self, selector: #selector(newLocationAdded(_:)), name: .newLocationSaved, object: nil)
  }

  func getMapAnnotations() -> [Station] {
    var annotations:Array = [Station]()
    
    let pListFileURL = Bundle.main.url(forResource: "dataset", withExtension: "plist", subdirectory: "")
    
    if let pListPath = pListFileURL?.path,
      let pListData = FileManager.default.contents(atPath: pListPath) {
      
      do {
        let pListArray = try PropertyListSerialization.propertyList(from: pListData, options:PropertyListSerialization.ReadOptions(), format:nil) as! [Dictionary<String, AnyObject>]

        for item in pListArray {
          let lat = item["Latitude"] as! Double
          let long = item["Longitude"] as! Double
          
          let annotation = Station(latitude: lat , longitude: long)
          annotation.title = item["Name"] as! String
          annotation.subtitle = item["Type"] as! String
          
          annotations.append(annotation)
        }
      } catch {
        print("Error reading regions plist file: \(error)")
      }
      
      print(annotations)
    }
    
    return annotations
  }
  
  @IBAction func addItemPressed(_ sender: Any) {
    guard let currentLocation = mapView.userLocation.location else {
      return
    }
    LocationsStorage.shared.saveCLLocationToDisk(currentLocation)
  }
  
  func annotationForLocation(_ location: Location) -> MKAnnotation {
    let annotation = MKPointAnnotation()
    annotation.title = location.dateString
    annotation.coordinate = location.coordinates
    return annotation
  }
  
  @objc func newLocationAdded(_ notification: Notification) {
    guard let location = notification.userInfo?["location"] as? Location else {
      return
    }
    
    let annotation = annotationForLocation(location)
    mapView.addAnnotation(annotation)
  }
}
