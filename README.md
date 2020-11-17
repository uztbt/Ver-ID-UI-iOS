![Cocoapods](https://img.shields.io/cocoapods/v/Ver-ID-UI.svg)

# Ver-ID UI for iOS

## Prerequisites
Minimum iOS version is 10.3.

To build this project and to run the sample app you will need a Apple Mac computer with these applications:

- [Xcode](https://itunes.apple.com/us/app/xcode/id497799835)
- [Git](https://git-scm.com)
- [CocoaPods](https://cocoapods.org)

## Installation

1. Open **Terminal** and enter the following commands:

	~~~shell
	git clone https://github.com/AppliedRecognition/Ver-ID-UI-iOS.git
	cd Ver-ID-UI-iOS
	pod install
	open VerIDUI.xcworkspace
	~~~

1. The **VerIDUI.xcworkspace** should now be open in **Xcode**.
1. You can now build and run the **Ver-ID Sample** target on your iOS device.

## Adding Ver-ID to your own project

1. [Register your app](https://dev.ver-id.com/licensing/). You will need your app's bundle identifier.
2. Registering your app will generate an evaluation licence for your app. The licence is valid for 30 days. If you need a production licence please [contact Applied Recognition](mailto:sales@appliedrec.com).
2. When you finish the registration you'll receive a file called **Ver-ID identity.p12** and a password. Copy the password to a secure location and add the **Ver-ID identity.p12** file in your app:    
    - Open your project in Xcode.
    - From the top menu select **File/Add files to “[your project name]”...** or press **⌥⌘A** and browse to select the downloaded **Ver-ID identity.p12** file.
    - Reveal the options by clicking the **Options** button on the bottom left of the dialog.
    - Tick **Copy items if needed** under **Destination**.
    - Under **Added to targets** select your app target.
8. Ver-ID will need the password you received at registration to construct an instance of `VerIDSDKIdentity`.    
    - You can either specify the password when you create an instance of `VerIDFactory`:

        ~~~swift
        let identity = try VerIDIdentity(password: "your password goes here")
        ~~~
    - Or you can add the password in your app's **Info.plist**:

        ~~~xml
        <key>com.appliedrec.verid.password</key>
        <string>your password goes here</string>
        ~~~
        
        and construct the identity without the password parameter:
        
        ~~~swift
        let identity = try VerIDIdentity()        
        ~~~
1. Pass the instance of `VerIDIdentity` to the `VerIDFactory` constructor:

    ~~~swift
    let veridFactory = VerIDFactory(identity: identity)
    ~~~
        
1. If your project is using [CocoaPods](https://cocoapods.org) for dependency management, open the project's **Podfile**. Otherwise make sure CocoaPods is installed and in your project's folder create a file named **Podfile** (without an extension).
1. Let's assume your project is called **MyProject** and it has an app target called **MyApp**. Open the **Podfile** in a text editor and enter the following:

    ~~~ruby
    project 'MyProject.xcodeproj'
    workspace 'MyProject.xcworkspace'
    platform :ios, '10.3'
    target 'MyApp' do
        use_frameworks!
        pod 'Ver-ID-UI'
    
        # The following script sets the BUILD_LIBRARY_FOR_DISTRIBUTION build setting
        # to YES and removes the setting from the pod dependencies. Without it the
        # project will compile but it will fail to run. 
        post_install do |installer|
            installer.pods_project.build_configurations.each do |config|
                config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
            end
            installer.pods_project.targets.each do |target|
                target.build_configurations.each do |config|
                    config.build_settings.delete 'BUILD_LIBRARY_FOR_DISTRIBUTION'
                end
            end
        end
    end
    ~~~
    #### Please ensure that you include the `post_install` script. Your app will crash without it.
1. Save the Podfile. Open **Terminal** and navigate to your project's folder. Then enter:

	~~~shell
	pod install
	~~~
1. You can now open **MyProject.xcworkspace** in **Xcode** and Ver-ID will be available to use in your app **MyApp**.

## Running Ver-ID sessions
1. Before running a Ver-ID UI session you will need to import the `VerIDCore` framework and create an instance of `VerID`.
1. Have your class implement the `VerIDFactoryDelegate` protocol. You will receive a callback when the `VerID` instance is created or when the creation fails.
1. In the class that runs the Ver-ID session import `VerIDUI`.
1. Pass the `VerID` instance to the `VerIDSession` constructor along with the session settings.

### Example

~~~swift
import UIKit
import VerIDCore
import VerIDUI

class MyViewController: UIViewController, VerIDFactoryDelegate, VerIDSessionDelegate {
    
    func runLivenessDetection() {
        guard let identity = try? VerIDSDKIdentity() else {
            // Failed to create SDK identity
            return
        }
        // You may want to display an activity indicator as the instance creation may take up to a few seconds
        let factory = VerIDFactory(identity: identity)
        // Set your class as the factory's delegate
        // The delegate methods will be called when the session is created or if the creation fails
        factory.delegate = self
        // Create an instance of Ver-ID
        factory.createVerID()
    }
    
    // MARK: - Ver-ID factory delegate
    
    func veridFactory(_ factory: VerIDFactory, didCreateVerID instance: VerID) {
        // Ver-ID instance was created
        // Create liveness detection settings
        let settings = LivenessDetectionSessionSettings()
        // Create a Ver-ID UI session
        let session = VerIDSession(environment: instance, settings: settings)
        // Set your class as a delegate of the session to receive the session outcome
        session.delegate = self
        // Start the session
        session.start()
    }
    
    func veridFactory(_ factory: VerIDFactory, didFailWithError error: Error) {
        NSLog("Failed to create Ver-ID instance: %@", error.localizedDescription)
    }
    
    // MARK: - Session delegate
    
    func didFinishSession(_ session: VerIDSession, withResult result: VerIDSessionResult) {
        // Session finished successfully
    }
    
    // MARK: Optional session delegate methods
    
    func didCancelSession(_ session: VerIDSession) {
        // Session was canceled
    }
    
    func shouldDisplayResult(_ result: VerIDSessionResult, ofSession session: VerIDSession) -> Bool {
        // Return `true` to display the result of the session
        return true
    }
    
    func shouldSpeakPromptsInSession(_ session: VerIDSession) -> Bool {
        // Return `true` to speak prompts in the session
        return true
    }
    
    func shouldRecordVideoOfSession(_ session: VerIDSession) -> Bool {
        // Return `true` to record a video of the session
        return true
    }
    
    func cameraPositionForSession(_ session: VerIDSession) -> AVCaptureDevice.Position {
        // Return `AVCaptureDevice.Position.back` to use the back camera instead of the front (selfie) camera
        return .back
    }
}
~~~

## API Reference Documentation
- [Ver-ID Core](https://appliedrecognition.github.io/Ver-ID-Core-Apple)
- [Ver-ID UI](https://appliedrecognition.github.io/Ver-ID-UI-iOS)
