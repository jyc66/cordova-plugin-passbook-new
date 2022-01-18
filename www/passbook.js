var passbook = exports;

var exec = require("cordova/exec");

/**
 * Pass
 *
 * @param {string} passTypeIdentifier
 * @param {string} serialNumber {string}
 * @param {string} passURL
 * @constructor
 */
var Pass = function (passTypeIdentifier, serialNumber, passURL) {
  this.passTypeIdentifier = passTypeIdentifier || null;
  this.serialNumber = serialNumber || null;
  this.passURL = passURL || null;
};

Pass.prototype.open = function () {
  passbook.openPass(this.passURL, null, null);
};

passbook.Pass = Pass;

/**
 *
 */
passbook.available = function () {
  return new Promise((resolve, reject) => {
    exec(
      resolve,
      reject,
      "Passbook",
      "available",
      []
    );
  });
};

/**
 * @param {Object}  { passIdentifier:String, passSerial:String }
 * @param resultCallback {Function} is called with result
 */
passbook.exists = function (callData) {
  return new Promise((resolve, reject) => {
    exec(
      function (result) {
        resolve(result);
      },
      function (err) {
        reject(err);
      },
      "Passbook",
      "passExists",
      [callData]
    );
  });
};

/**
 *
 * @param {Object}  url:String | { url:String, headers?:Object }
 */
passbook.downloadPass = function (callData) {
  return new Promise((resolve, reject) => {
    exec(
      function (result) {
        var pass = result.pass;
        resolve({
          pass: new Pass(
            pass.passTypeIdentifier,
            pass.serialNumber,
            pass.passURL
          ),
          isAdded: result.added,
        });
      },
      function (err) {
        reject(err);
      },
      "Passbook",
      "downloadPass",
      [callData]
    );
  });
};

/**
 *
 * @param file Local File URL, e.g. file:///path/pass.pkpass
 */
passbook.addPass = function (file) {
  return new Promise((resolve, reject) => {
    exec(
      function (result) {
        var pass = result.pass;
        resolve({
          pass: new Pass(
            pass.passTypeIdentifier,
            pass.serialNumber,
            pass.passURL
          ),
          isAdded: result.added,
        });
      },
      function (err) {
        reject(err);
      },
      "Passbook",
      "addPass",
      [file]
    );
  });
};

/**
 *
 * @param {Pass|string} passOrUrl
 * @param {Function} successCallback
 * @param {Function} errorCallback
 */
passbook.openPass = function (passOrUrl) {
  return new Promise((resolve, reject) => {
    exec(
      function (result) {
        resolve(result);
      },
      function (err) {
        reject(err);
      },
      "Passbook",
      "openPass",
      [passOrUrl]
    );
  });
};
