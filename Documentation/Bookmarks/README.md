# Bookmarks

The Bookmarks component will display a list of bookmarks in a table view and allows the user to select a bookmark and perform some action. 

## Bookmarks Behavior:

The `BookmarksTableViewController` can be created using either an `AGSGeoView` or an array of `AGSBookmark`s.

When created using an `AGSGeoView`, the default behavior when selecting a bookmark from the list is to pan/zoom the geoView to the bookmark's viewpoint and then dismiss the view controller.  Users can change this default behavior by supplying a custom handler to the `bookmarkSelectedHandler` property.

When created using an array of `AGSBookmarks`, there is no default `bookmarkSelectedHandler` and the user must provide their own.

Note that in all cases, supplying a `bookmarkSelectedHandler` requires users to also dismiss the `BookmarksTableViewController`, if desired.

The `BookmarksTableViewController` observes changes to the `map` or `scene` property on the `AGSGeoView` and also the map or scene's `bookmarks` property and will udpate the list of bookmarks accordingly.

## Usage

```swift
let bookmarksVC = BookmarksTableViewController.makeBookmarksTableViewController(geoView: mapView)
present(bookmarksVC, animated: true, completion: nil)
```

Setting the `bookmarkSelectedHandler` property to customize the selection behavior, in this case setting the viewpoint with a duration (animation):

```swift
let bookmarksVC = BookmarksTableViewController.makeBookmarksTableViewController(geoView: mapView)
bookmarksVC.bookmarkSelectedHandler  = { [weak self] (bookmark: AGSBookmark) in
    if let viewpoint = bookmark.viewpoint {
        self?.mapView.setViewpoint(viewpoint, duration: 2.0)
        
        //Note that when you provide a `bookmarkSelectedHandler` you are also respsonsible for dismissing the view controller, if desired.
        dismiss(animated: true)
    }
}
present(bookmarksVC, animated: true, completion: nil)
```

To see it in action, try out the [Examples](../../Examples) and refer to [BookmarksExample.swift](../../Examples/ArcGISToolkitExamples/BookmarksExample.swift) in the project.
