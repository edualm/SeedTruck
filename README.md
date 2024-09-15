<p align="center">
  <img width="256" height="256" src="https://raw.githubusercontent.com/edualm/SeedTruck/main/macOS/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png">
</p>

# Seed Truck

A seedbox management application for the whole family of Apple devices - iOS, macOS, tvOS and watchOS.

This is not the kind of project Apple allows on the App Store, so I'm open-sourcing it, hopefully it's useful for someone. You may also (and should!) use the app if you want, but you'll need to compile and install it yourself though.

It uses SwiftUI, and as such, can run on iOS/iPadOS/tvOS/watchOS/macOS.

## Supported Seedbox Software

 - Transmission
 
 And that's it, for now. The app's code is technically ready to easily support other torrent software, it just isn't implemented. Open a PR if you'd like to see support for others! 

## Screenshots

iOS screenshots for now; screenshots for other platforms will appear eventually.

<img width="300" src="https://raw.githubusercontent.com/edualm/SeedTruck/main/Screenshots/Torrent%20Listing%20-%20Light.png">&nbsp;&nbsp;&nbsp;<img width="300" src="https://raw.githubusercontent.com/edualm/SeedTruck/main/Screenshots/Torrent%20Detail%20-%20Light.png">

<img width="300" src="https://raw.githubusercontent.com/edualm/SeedTruck/main/Screenshots/Torrent%20Listing%20-%20Dark.png">&nbsp;&nbsp;&nbsp;<img width="300" src="https://raw.githubusercontent.com/edualm/SeedTruck/main/Screenshots/Torrent%20Detail%20-%20Dark.png">

## Features

 - Connect to Transmission seedboxes (support for other types of seedboxes is easy to add, but not implemented).
 - View torrents, their status, and remove them.
 - Import torrents, either using a torrent file or magnet link.

## Tests

Not many were written since I wasn't being able to run them under Xcode 12. I should fix that probably...

## License

MIT
