<p align="center">
  <img width="256" height="256" src="https://raw.githubusercontent.com/edualm/SeedTruck/main/Shared/Assets.xcassets/AppIcon.appiconset/Icon-1024.png">
</p>

# Seed Truck

A seedbox management application for the whole family of Apple devices - iOS, macOS, tvOS and watchOS.

This is not the kind of project Apple allows on the App Store, so I'm open-sourcing it, hopefully it's useful for someone. You may also (and should!) use the app if you want, but you'll need to compile and install it yourself though.

It uses SwiftUI 2, and as such, can only run on iOS/iPadOS/tvOS 14+, watchOS 7+ and macOS 11+.

## Status

| Platform | Status | Development Status | Additional Info |
| --- | --- | --- |
| iOS | ✅ | "Released" | Appears to be stable on day-to-day use. |
| iPadOS | ✅ | "Released" | Appears to be stable, but was not throughly tested. |
| macOS | ⚠️ | Alpha / Under active development. | Alpha. Feature complete, but probably buggy. |
| tvOS | ✅ | "Released". | Appears to be stable, but was not throughly tested. |
| watchOS | ✅ | "Released" | Appears to be stable on day-to-day use. |

## Screenshots

iOS screenshots for now; screenshots for other platforms will appear eventually.

<img width="300" src="https://raw.githubusercontent.com/edualm/SeedTruck/main/Screenshots/Torrent%20Listing%20-%20Light.png">&nbsp;&nbsp;&nbsp;<img width="300" src="https://raw.githubusercontent.com/edualm/SeedTruck/main/Screenshots/Torrent%20Detail%20-%20Light.png">

<img width="300" src="https://raw.githubusercontent.com/edualm/SeedTruck/main/Screenshots/Torrent%20Listing%20-%20Dark.png">&nbsp;&nbsp;&nbsp;<img width="300" src="https://raw.githubusercontent.com/edualm/SeedTruck/main/Screenshots/Torrent%20Detail%20-%20Dark.png">

## Features

 - Connect to Transmission seedboxes (support for other types of seedboxes is easy to add, but not implemented).
 - View torrents, their status, and remove them.
 - Import torrents, either using a torrent file or magnet link.
 
iOS, tvOS and watchOS support are practically done. macOS support will only probably be worked on when macOS 11 is released.

## Tests

Not many were written since I wasn't being able to run them under Xcode 12. I should fix that probably...

## License

MIT
