# TemplatePickerViewController

The `TemplatePickerViewController` is a `UIViewController` subclass that allows the user to choose from a list of `AGSFeatureTemplates`. This is a common use case for creating a new feature. 

### Usage

```swift

// Instantiate the TemplatePickerViewController with a map
let templatePicker = TemplatePickerViewController(map: map)

// assign the delegate
templatePicker.delegate = self

// Embed the TemplatePickerViewController in a UINavigationController, and present it
let navigationController = UINavigationController(rootViewController: templatePicker)
navigationController.modalPresentationStyle = .formSheet
UIApplication.shared.topViewController()?.present(navigationController, animated: true)
```

To see it in action, try out the [Examples](../../Examples) and refer to [PopupExample.swift](../../Examples/ArcGISToolkitExamples/PopupExample.swift) in the project.




