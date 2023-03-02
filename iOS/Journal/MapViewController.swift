import UIKit
import MapKit
import AVFoundation

class Station: NSObject, MKAnnotation {
  var id: Int?
  var title: String?
  var subtitle: String?
  var latitude: Double
  var longitude: Double
  
  var coordinate: CLLocationCoordinate2D {
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  init(latitude: Double, longitude: Double) {
    self.latitude = latitude
    self.longitude = longitude
  }
}

class MapViewController: UIViewController, MKMapViewDelegate {
  @IBOutlet weak var mapView: MKMapView!
  
  var annotations : [Station] = []
  var idsLastTTS : [Int] = []
  
  let distanceThreshold : Double = 100
  let synthesizer = AVSpeechSynthesizer()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    guard let path = Bundle.main.path(forResource: "dataset", ofType: "plist") else {return}
    
    let url = URL(fileURLWithPath: path)
    let data = try! Data(contentsOf: url)

    annotations = getMapAnnotations()
    mapView.addAnnotations(annotations)
    mapView.userTrackingMode = .followWithHeading
    mapView.delegate = self
    
    NotificationCenter.default.addObserver(self, selector: #selector(newLocationAdded(_:)), name: .newLocationSaved, object: nil)
  }

  func getMapAnnotations() -> [Station] {
    var annotations:Array = [Station]()
    var id = 0
    
    let pListFileURL = Bundle.main.url(forResource: "dataset", withExtension: "plist", subdirectory: "")
    
    if let pListPath = pListFileURL?.path,
      let pListData = FileManager.default.contents(atPath: pListPath) {
      
      do {
        let pListArray = try PropertyListSerialization.propertyList(from: pListData, options:PropertyListSerialization.ReadOptions(), format:nil) as! [Dictionary<String, AnyObject>]

        for item in pListArray {
          let lat = item["Latitude"] as! Double
          let long = item["Longitude"] as! Double
          
          let annotation = Station(latitude: lat , longitude: long)
          annotation.id = id
          annotation.title = item["Name"] as? String
          annotation.subtitle = item["Type"] as? String

          annotations.append(annotation)
          
          id += 1
        }
      } catch {
        print("Error reading regions plist file: \(error)")
      }
    }
    
    return annotations
  }
  
  func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
    let location = CLLocation(latitude: (userLocation.location?.coordinate.latitude)!, longitude: (userLocation.location?.coordinate.longitude)!)
    
    var nearbyAnnotations:Array = [Station]()
    
    for item in annotations {
      let annotation = CLLocation(latitude: item.latitude, longitude: item.longitude)
      let distance = location.distance(from: annotation)
      
      if(distance < distanceThreshold) {
        nearbyAnnotations.append(item)
      }
    }
    
    var voiceOverText = ""
    var voiceOverIds : [Int] = []
    
    for item in nearbyAnnotations {
      let annotation = CLLocation(latitude: item.latitude, longitude: item.longitude)
      
      voiceOverText += calculateUserAngle(user: location, annotation: annotation)
      voiceOverText += item.subtitle! + ", " + item.title! + ". "
      
      voiceOverIds.append(item.id!)
    }

    if(!voiceOverIds.containsSameElements(as: idsLastTTS)) {
      let utterance = AVSpeechUtterance(string: voiceOverText)
      utterance.voice = AVSpeechSynthesisVoice(language: "pt-PT")
      
      synthesizer.speak(utterance)
      
      idsLastTTS = voiceOverIds
    }

  }
  
  func calculateUserAngle(user: CLLocation, annotation: CLLocation) -> String {
    var text = "";
    
    if(annotation.coordinate.latitude > user.coordinate.latitude && annotation.coordinate.longitude > user.coordinate.longitude) {
      text = "À sua frente, à direita, você encontrará "
    } else if(annotation.coordinate.latitude > user.coordinate.latitude && annotation.coordinate.longitude < user.coordinate.longitude) {
      text = "Atrás de você, à direita, você encontrará "
    } else if(annotation.coordinate.latitude < user.coordinate.latitude && annotation.coordinate.longitude < user.coordinate.longitude) {
      text = "Atrás de você, à esquerda, você encontrará "
    } else if(annotation.coordinate.latitude < user.coordinate.latitude && annotation.coordinate.longitude > user.coordinate.longitude) {
      text = "À sua frente, à esquerda, você encontrará "
    }
    
    return text
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

extension Array where Element: Comparable {
    func containsSameElements(as other: [Element]) -> Bool {
        return self.count == other.count && self.sorted() == other.sorted()
    }
}
