StackMob iOS SDK
================

## [StackMob Site](https://www.stackmob.com)

## [Developer Guide](https://developer.stackmob.com/ios-sdk/developer-guide)

## [Apple Docs](http://stackmob.github.com/stackmob-ios-sdk/index.html)

<br/>

# Getting started

## Add the StackMob SDK to your app

### Using CocoaPods

[CocoaPods](https://github.com/CocoaPods/CocoaPods) is a dependency management tool for iOS apps. Using it you can easily express the external libraries (like StackMob) your app relies on and install them.

Create a new iOS project in Xcode. Here we've created an app named "MobFind".

		$ cd MobFind
		$ ls -F
		MobFind/  MobFind.xcodeproj/  MobFindTests//

We need to create a Podfile to contain our project's configuration for CocoaPods.

		$ touch Podfile
		$ open Podfile 

Your Podfile defines your app's dependencies on other libraries. Add StackMob to it.

		platform :ios, '5.0'
		pod 'StackMob', '2.0.0'

Now you can use CocoaPods to install your dependencies.

		$ pod install
				
Your now have a workspace containing your app's project and a project build by CocoaPods which will build a static library containing all of the dependencies listed in your Podfile.
		
		$ ls -F 
		MobFind/  MobFind.xcodeproj/  MobFind.xcworkspace/  MobFindTests/  Podfile  		Podfile.lock  Pods/
		
Open the new workspace and we can start developing using the StackMob library

		$ open MobFind.xcworkspace

## Configure the StackMob SDK to use your StackMob account

# Development

## Debugging
<br/>

<p>The iOS SDK gives developers access to two global variables that will enable additional logging statements when using the Core Data integration:</p>

* **SM_CORE_DATA_DEBUG** - In your AppDelegate's `application:DidFinishLaunchingWithOptions:` method, include the line `SM_CORE_DATA_DEBUG = YES;` to turn on log statements from `SMIncrementalStore`. This will provide information about the data store calls to StackMob happening behind the scenes during Core Data saves and fetches. The default is `NO`.
* **SM_MAX_LOG_LENGTH** - Used to control how many characters are printed when logging objects. The default is **10,000**, which is plenty, so you will almost never have to set this.  The only time you will see the string representation of an object truncated is when you have an Attribute of type String that maps to a field of type Binary on StackMob, because you are sending a string containing the binary of the image, etc. String representations of objects that have been truncated end with \<MAX\_LOG\_LENGTH\_REACHED\>.   


## Testing

<br/>
<p>In order to test you must download the full source code: `git clone git@github.com:stackmob/stackmob-ios-sdk.git`.</p>


[Kiwi](https://github.com/allending/Kiwi) specs run just like OCUnit tests. In Xcode `⌘U` will run all the tests for the currently selected scheme.

		describe(@"a public method or feature", ^{
			beforeEach(^{
				//set up
				[[someClass stubAndReturn:aResult] aMethod];
			});
			context(@"when some precondition exists", ^{
				beforeEach(^{
					//set the precondition
				});
				it(@"should have a specific behavior", ^{
					//verify the behavior
					[[aThing shouldNot] equal:someOtherThing];
				});
			    pending(@"should eventually have another behavior", ^{
			    	//pending specs will not execute and generate warnings
			    	[[[anObject should] receive] aMethodWith:anArgument];
			    	[anObject doStuff];
			    });
			    context(@"and another condition exists", ^{
			    	//...
			    });
			});
		});
		
### Integration Tests

Unit tests do not make network requests against StackMob. The project includes a seperate target of integration tests to verify communication with the StackMob API.

1. `cp integration\ tests/StackMobCredentials.plist.example integration\ tests/StackMobCredentials.plist`
2. `open integration\ tests/StackMobCredentials.plist`
3. Set the public for the StackMob account you want the tests to use.
4. Create a schema (using the StackMob web console) called `places`. Add
   a geopoint field called `location` and set all Schema Permissions to `Open`.
5. Create a schema (using the StackMob web console) called `oauth2test`. Add a string field called `name` and set all Schema Permissions to `Allow to any logged in user`.
6. Test the "integration tests" scheme.

#### Optional: Test Custom Code Methods
<br/>
By default, custom code tests are turned off.  This is because they require you to have specific custom code methods uploaded for your application. To test custom code, do the following:

1. Clone the custom code example repository: `$ git clone git@github.com:stackmob/stackmob-customcode-example.git`.
2. From the root folder navigate to `/java/src/main/java/com/stackmob/example/`.
3. Replace the contents of the `/example` folder with the files provided by stackmob-ios-sdk.  They can be found by navigating from the root of your local stackmob-ios-sdk folder to `/integration tests/CustomCodeFiles`.  The files are `EntryPointExtender.java`, `HelloWorld.java`, and `HelloWorldParams.java`.
4. Naviagate back to the root of your local stackmob-customcode-example folder and execute the command `$ mvn clean package`.
5. Go to your dashboard on `stackmob.com` and click on `Manage Custom Code` in the left sidebar.
6. Upload new code and choose the `.jar` file located, from the root of your local stackmob-customcode-example folder, in `/java/target/`.  It's the only `.jar` file there, and NOT the `.one-jar.jar`.  You should get feedback from the browser that the methods `hello_world` and `hello_world_params` have successfully been uploaded - it reports the version and create date.
7. Once you upload the custom code files you are ready to test.  In Xcode, navigate to the file `SMIntegrationTestHelpers.h` in the folder `Integration Tests`.  You will see `#define TEST_CUSTOM_CODE 0`.  Just change that to a `1` and when you test the "integration tests" scheme you will run the custom code tests found in `SMCusCodeReqIntegrationSpec.m`.



## Submitting pull requests

0. Fork the repository on github and clone your fork.
1. Create a topic branch: `git checkout -b make_sdk_better development`.
2. Write some tests for your change.
3. Make the tests pass.
4. Commit your changes.
5. (Repeat Steps 2-4 as needed.)
6. Make sure your topic branch is up to date with any changes other developers have added to the development branch while you were working: `git merge development` (`git rebase development` for local branches if you prefer).
7. Push your topic branch to your fork: `git push origin make_sdk_better`.
8. Create a pull request on github asking StackMob to merge your topic branch into StackMob's **development** branch.
