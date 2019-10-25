# Bookmarks

The Bookmarks component will display a list of bookmarks in a table view and allows the user to select a bookmark and perform some action. 

## Bookmarks Behavior:

The `BookmarksTableViewController` can be created using either an `AGSGeoView` or an array of `AGSBookmark`s.

When created using an `AGSGeoView`, selecting a bookmark from the list will pan/zoom the geoView to the bookmark's viewpoint.  Users can change this default behavior by supplying a custom handler to the `selectAction` property.

When created using an array of `AGSBookmarks`, there is no default `selectAction` and the user must provide their own.

## Usage

```swift
let bookmarksVC = BookmarksTableViewController.makeBookmarksTableViewController(geoView: mapView)
present(bookmarksVC, animated: true, completion: nil)
```

Setting the `selectAction` property to customize the selection behavior, in this case setting the viewpoint with a duration (animation):

```swift
let bookmarksVC = BookmarksTableViewController.makeBookmarksTableViewController(geoView: mapView)
bookmarksVC.selectAction  = { [weak self] (bookmark: AGSBookmark) in
    if let viewpoint = bookmark.viewpoint {
        self?.mapView.setViewpoint(viewpoint, duration: 2.0)
    }
}
present(bookmarksVC, animated: true, completion: nil)
```

To see it in action, try out the [Examples](../../Examples) and refer to [BookmarksExample.swift](../../Examples/ArcGISToolkitExamples/BookmarksExample.swift) in the project.
