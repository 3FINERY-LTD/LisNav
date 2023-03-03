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
  var isProcessing : Bool = false
  
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
    
    if(!isProcessing) {
      isProcessing = true
      
      getAddressFromLatLon(userLocation: userLocation)
    }
  }
  
  func calculateUserAngle(user: CLLocation, annotation: CLLocation, heading: CLLocationDirection?) -> String {
    var text : String = ""
    var degrees : Double = 0
    
    if(heading != nil) {
      if(annotation.coordinate.latitude > user.coordinate.latitude && annotation.coordinate.longitude > user.coordinate.longitude) {
        degrees = 45;
      } else if(annotation.coordinate.latitude > user.coordinate.latitude && annotation.coordinate.longitude < user.coordinate.longitude) {
        degrees = 135
      } else if(annotation.coordinate.latitude < user.coordinate.latitude && annotation.coordinate.longitude < user.coordinate.longitude) {
        degrees = 225
      } else if(annotation.coordinate.latitude < user.coordinate.latitude && annotation.coordinate.longitude > user.coordinate.longitude) {
        degrees = 315
      }
      
      degrees += heading ?? 0
      
      if(degrees > 360) {
        degrees -= 360
      }
      
      if(degrees > 0 && degrees <= 90) {
        text = "À sua frente, à direita, você encontrará "
      } else if(degrees > 90 && degrees <= 180) {
        text = "Atrás de você, à direita, você encontrará "
      } else if(degrees > 180 && degrees <= 270) {
        text = "Atrás de você, à esquerda, você encontrará "
      } else if(degrees > 270 && degrees <= 360) {
        text = "À sua frente, à esquerda, você encontrará "
      }
    }
    
    return text
  }
  
  func getAddressFromLatLon(userLocation: MKUserLocation) {
    let geocoder : CLGeocoder = CLGeocoder()
    let location = CLLocation(latitude: (userLocation.location?.coordinate.latitude)!, longitude: (userLocation.location?.coordinate.longitude)!)
    
    geocoder.reverseGeocodeLocation(location, completionHandler: {(placemarks, error) in
      if (error != nil) {
        print("reverse geodcode fail: \(error!.localizedDescription)")
      }
      
      let pm = placemarks as [CLPlacemark]?
      
      if pm != nil {
        if pm!.count > 0 {
          let pm = placemarks![0]

          self.getAnnotationsFromLatLong(userLocation: userLocation, streetAddress: pm.thoroughfare)
        }
      }
    })
  }
  
  func getAnnotationsFromLatLong(userLocation: MKUserLocation, streetAddress: String?) {
    let location = CLLocation(latitude: (userLocation.location?.coordinate.latitude)!, longitude: (userLocation.location?.coordinate.longitude)!)
    
    if(userLocation.heading?.magneticHeading != nil) {
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
      
      if(streetAddress != nil) {
        voiceOverText = "Você está na " + streetAddress! + ". "
      }
      
      for item in nearbyAnnotations {
        let annotation = CLLocation(latitude: item.latitude, longitude: item.longitude)
        
        voiceOverText += calculateUserAngle(user: location, annotation: annotation, heading: userLocation.heading?.magneticHeading)
        voiceOverText += item.subtitle! + ", " + item.title! + ". "
        
        voiceOverIds.append(item.id!)
      }
      
      if(!synthesizer.isSpeaking && !voiceOverIds.containsSameElements(as: idsLastTTS)) {
        let utterance = AVSpeechUtterance(string: voiceOverText)
        utterance.voice = AVSpeechSynthesisVoice(language: "pt-PT")
        
        synthesizer.speak(utterance)
        idsLastTTS = voiceOverIds
      }
      
      isProcessing = false
      //speechSynthesizer.outputChannels = channels
    }
  }
  
  
  /*func initalizeSpeechForRightChannel() -> [AVAudioSessionChannelDescription] {
      let avSession = AVAudioSession.sharedInstance()
      let route = avSession.currentRoute
      let outputPorts = route.outputs
    
    var channels:[AVAudioSessionChannelDescription] = []
    
      var leftAudioChannel:AVAudioSessionChannelDescription? = nil
      var leftAudioPortDesc:AVAudioSessionPortDescription? = nil
      
    for  outputPort in outputPorts {
          for channel in outputPort.channels! {
              leftAudioPortDesc = outputPort
              //print("Name: \(channel.channelName)")
              if channel.channelName == "Headphones Left" {
                  channels.append(channel)
                  leftAudioChannel = channel
              }else {
                 // leftAudioPortDesc?.channels?.removeObject(channel)
              }
          }
      }

      if channels.count > 0 {
          if #available(iOS 10.0, *) {
              print("Setting Left Channel")
              
              print("Checking output channel : \(speechSynthesizer.outputChannels?.count)")

          } else {
              // Fallback on earlier versions
              }
          }
      }*/
  
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
