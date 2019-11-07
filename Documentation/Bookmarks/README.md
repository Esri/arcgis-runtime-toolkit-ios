# Bookmarks

The Bookmarks component will display a list of bookmarks in a table view and allows the user to select a bookmark and perform some action. 

## Bookmarks Behavior:

The `BookmarksTableViewController` can be created using either an `AGSGeoView` or an array of `AGSBookmark`s.

Clients must set the `delegate` property and implement the `bookmarksViewController:didSelect` delegate method in order to be notified when a bookmark is selected.

The `BookmarksTableViewController` observes changes to the `map` or `scene` property on the `AGSGeoView` and also the map or scene's `bookmarks` property and will udpate the list of bookmarks accordingly.

## Usage

```swift
bookmarksVC = BookmarksViewController(geoView: mapView)
bookmarksVC?.delegate = self

...

func bookmarksViewController(_ controller: BookmarksViewController, didSelect bookmark: AGSBookmark) {
    if let viewpoint = bookmark.viewpoint {
        mapView.setViewpoint(viewpoint, duration: 2.0)
        dismiss(animated: true)
    }
}
```

To see it in action, try out the [Examples](../../Examples) and refer to [BookmarksExample.swift](../../Examples/ArcGISToolkitExamples/BookmarksExample.swift) in the project.
