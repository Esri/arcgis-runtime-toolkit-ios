# TemplatePickerViewController

The `TemplatePickerViewController` is a `UIViewController` subclass that allows the user to choose from a list of `AGSFeatureTemplates`. This is a common use case for creating a new feature. 

### Usage

```swift

// Instantiate the TemplatePickerViewController
let templatePicker = TemplatePickerViewController(map: map)

// Assign the delegate
templatePicker.delegate = self

// Present the template picker
navigationController?.pushViewController(templatePicker, animated: true)
```

To see it in action, try out the [Examples](../../Examples) and refer to [TemplatePickerExample.swift](../../Examples/ArcGISToolkitExamples/TemplatePickerExample.swift) in the project.
