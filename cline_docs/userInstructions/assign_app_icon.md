# Assigning the App Icon in Xcode

1.  Open your `OpenCone.xcodeproj` project in Xcode.
2.  In the Project Navigator (left sidebar), find and click on `Assets.xcassets`.
3.  Select `AppIcon` from the list of assets.
4.  You should see placeholders for various icon sizes. Drag the file `AppIcon-Source-1024.png` (located in the `OpenCone/Assets.xcassets/AppIcon.appiconset/` folder) onto the `iOS App Icon` placeholder (it's usually the largest one, marked 1024pt).
5.  Xcode should automatically generate all the required smaller icon sizes from this source image.
6.  Build and run your app to confirm the new icon is displayed.
