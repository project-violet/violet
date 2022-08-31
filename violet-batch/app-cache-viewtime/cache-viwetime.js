//===----------------------------------------------------------------------===//
//
//                            Violet Batch
//
//===----------------------------------------------------------------------===//
//
//  Copyright (C) 2022. violet-team. All Rights Reserved.
//
//===----------------------------------------------------------------------===//

const a_syncdatabase = require("./api/syncdatabase");

const path = require("path");
const fs = require("fs");

async function checkCacheExists() {
  const files = fs.readdirSync(".");

  return files.some((e) => e.startsWith("viewtime-cache-"));
}

// https://fuzzytolerance.info/blog/2019/07/19/The-better-way-to-do-natural-sort-in-JavaScript/
function naturalSort(a, b) {
  var re =
      /(^([+\-]?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?(?=\D|\s|$))|^0x[\da-fA-F]+$|\d+)/g,
    sre = /^\s+|\s+$/g, // trim pre-post whitespace
    snre = /\s+/g, // normalize all whitespace to single ' ' character
    dre =
      /(^([\w ]+,?[\w ]+)?[\w ]+,?[\w ]+\d+:\d+(:\d+)?[\w ]?|^\d{1,4}[\/\-]\d{1,4}[\/\-]\d{1,4}|^\w+, \w+ \d+, \d{4})/,
    hre = /^0x[0-9a-f]+$/i,
    ore = /^0/,
    i = function (s) {
      return (
        (naturalSort.insensitive && ("" + s).toLowerCase()) ||
        "" + s
      ).replace(sre, "");
    },
    // convert all to strings strip whitespace
    x = i(a),
    y = i(b),
    // chunk/tokenize
    xN = x
      .replace(re, "\0$1\0")
      .replace(/\0$/, "")
      .replace(/^\0/, "")
      .split("\0"),
    yN = y
      .replace(re, "\0$1\0")
      .replace(/\0$/, "")
      .replace(/^\0/, "")
      .split("\0"),
    // numeric, hex or date detection
    xD = parseInt(x.match(hre), 16) || (xN.length !== 1 && Date.parse(x)),
    yD =
      parseInt(y.match(hre), 16) ||
      (xD && y.match(dre) && Date.parse(y)) ||
      null,
    normChunk = function (s, l) {
      // normalize spaces; find floats not starting with '0', string or 0 if not defined (Clint Priest)
      return (
        ((!s.match(ore) || l == 1) && parseFloat(s)) ||
        s.replace(snre, " ").replace(sre, "") ||
        0
      );
    },
    oFxNcL,
    oFyNcL;
  // first try and sort Hex codes or Dates
  if (yD) {
    if (xD < yD) {
      return -1;
    } else if (xD > yD) {
      return 1;
    }
  }
  // natural sorting through split numeric strings and default strings
  for (
    var cLoc = 0, xNl = xN.length, yNl = yN.length, numS = Math.max(xNl, yNl);
    cLoc < numS;
    cLoc++
  ) {
    oFxNcL = normChunk(xN[cLoc] || "", xNl);
    oFyNcL = normChunk(yN[cLoc] || "", yNl);
    // handle numeric vs string comparison - number < string - (Kyle Adams)
    if (isNaN(oFxNcL) !== isNaN(oFyNcL)) {
      return isNaN(oFxNcL) ? 1 : -1;
    }
    // if unicode use locale comparison
    if (/[^\x00-\x80]/.test(oFxNcL + oFyNcL) && oFxNcL.localeCompare) {
      var comp = oFxNcL.localeCompare(oFyNcL);
      return comp / Math.abs(comp);
    }
    if (oFxNcL < oFyNcL) {
      return -1;
    } else if (oFxNcL > oFyNcL) {
      return 1;
    }
  }
}

async function getLatestCachedViewtimeId() {
  const files = fs.readdirSync(".");
  const caches = files.filter((e) => e.startsWith("viewtime-cache-"));

  caches.sort((a, b) => -naturalSort(a, b));

  const latestCacheFile = caches[0];

  console.log(latestCacheFile);
}

async function cacheViewTime() {
  const conn = a_syncdatabase();

  const qlength = conn.query("SELECT MAX(Id) as C FROM viewtime");

  if (qlength === undefined || qlength === null)
    throw new Error("length query error");

  if (qlength.length == 0 || qlength[0] === undefined)
    throw new Error("length query error");

  const length = qlength[0]["C"];

  console.log("LEN: " + length);

  const iter = length / 500000;

  for (var i = 0; i <= iter; i++) {
    const data = conn.query(
      `SELECT Id, TimeStamp, ArticleId, UserAppId FROM viewtime WHERE ViewSeconds >= 24
        order by Id limit 500000 offset ${i * 500000}`
    );

    const dataPath = path.resolve(__dirname, `viewtime-cache-${i}.json`);

    console.log(`iter: ${i}/${iter}, ${data.length}`);

    if (data.length === 0) break;

    fs.writeFileSync(
      dataPath,
      JSON.stringify(
        data.map(
          (x) =>
            "(" +
            x["Id"] +
            "," +
            x["ArticleId"] +
            "," +
            x["TimeStamp"] +
            "," +
            x["UserAppId"] +
            ")"
        )
      ),
      function (err) {
        console.log(err);
        process.exit();
      }
    );
  }
}

// checkCacheExists();
cacheViewTime();
// getLatestCachedViewtimeId();
