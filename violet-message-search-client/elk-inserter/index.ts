
const merged = "G:\\Dev2\\violet-message-search-local\\dist\\fscm\\merged.json";

import fs from "fs";
import elasticsearch from "elasticsearch";
const client = new elasticsearch.Client({
  hosts: ["http://localhost:9200"],
  httpAuth: 'elastic:abc123',
});

fs.readFile(merged, "utf8", async (error: any, jsonFile: string) => {
  var items: any[] = JSON.parse(jsonFile);

  for (var j = 0; j < items.length;) {
    var insertrr = [];

    for (var i = 0; j < items.length && i < 100000; i++, j++) {
      insertrr.push({index:{_index:"test"}});
      insertrr.push(items[j])
    }

    await client.bulk({
      body: insertrr
    });

    console.log(`${j}/${items.length}`);
  }
});