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
      `SELECT TimeStamp, ArticleId, UserAppId FROM viewtime WHERE ViewSeconds >= 24
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

cacheViewTime();
