# Cordova Plugin Passbook New
This is forked version of [cordova-plugin-passbook](https://github.com/passslot/cordova-plugin-passbook). Due to naming difference between package name and plugin name, there were various issues with cordova installation which are now fixed with common name `cordova-plugin-passbook-new`.

There was also a bug [#10](https://github.com/passslot/cordova-plugin-passbook/issues/10) on github which breaks browser history, which is now fixed with commenting code as per mentioned in the issue itself.

I don't recommend downloading `.pkpass` file using `Passbook.downloadPass()` function as it does not send cookies or any headers. Instead download `.pkpass` file using `axios` or `fetch` HTTP API, save it on the device and open with `passbook.addPass(file)` where `file` is local device path to the file.


## Installation
    cordova plugin add cordova-plugin-passbook-new