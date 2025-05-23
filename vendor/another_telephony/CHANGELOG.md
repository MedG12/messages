## 0.4.1
* Fix on namespace erorr when building flutter 3.29 [#10](https://github.com/thanhdang198/Telephony/pull/10), thanks [IamMuuo](https://github.com/IamMuuo)
* Remove iOS configuration [#7](https://github.com/thanhdang198/Telephony/pull/7), thánk [ali2236](https://github.com/ali2236)
## 0.2.5
* Correctly podspec file for iOS
* Fix README.md documentation
## 0.2.4
* Remove unnecessary log
* Upgrade build gradle to `7.1.3`
* Upgrade kotlin version to `1.9.22`
## 0.2.3
* Update dev library version
## 0.2.2
* Update README.md
## 0.2.1
* Fix receiver message in background 
## 0.2.0
* Upgrade `minSdk` to 23
* Upgrade `targetSdk` to 31
* Upgrade min dart sdk to 2.15.1
* Fix SmsMethodCallHandler error.
* Added Service Center field in SmsMessage

## 0.1.4
* Fix SmsType parsing (Contributor: https://github.com/Mabsten)
* Remove SmsMethodCallHandler trailing comma.

## 0.1.3
* Fix background execution (Contributor: https://github.com/meomap)

## 0.1.2
* Change invokeMethod call type for getSms methods to List? (No change to telephony API)

## 0.1.1
* Added background instance for executing telephony methods in background.
* Fix type cast issues.

## 0.1.0
* Feature equivalent of v0.0.9
* Enabled null-safety

## 0.0.9
* Fix sendSms Future never completes.

## 0.0.8
* Upgrade platform version.

## 0.0.7
* Fix build error when plugin included in iOS project.

## 0.0.6
* Multipart messages are grouped as one single SMS so that listenSms functions only get triggered once.

## 0.0.5
* Fix background execution error due to FlutterLoader.getInstance() deprecation.

## 0.0.4

#### New Features:
* Start phone calls from default dialer or directly from the app.

## 0.0.3

#### Changes:
* Fix unresponsive foreground methods after starting background isolate.


## 0.0.2

#### Possible breaking changes:
* sendSms functions are now async.

#### Other changes:
* Adding documentation.
* Fix conflicting class name (Column --> TelephonyColumn).
* Update plugin description.


## 0.0.1

* First release of telephony

