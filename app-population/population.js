const path = require("path");
const fs = require("fs");

async function _buildPopulation() {
  var rr = {};

  for (var i = 0; i < 30; i++) {
    const dataPath = path.resolve(
      __dirname,
      "../app-cache-viewtime/viewtime-cache-" + i.toString() + ".json"
    );
    var j = JSON.parse(fs.readFileSync(dataPath));

    for (var x of j) {
      const id = x.split(",")[1].split(",")[0];
      if (id in rr) rr[id] += 1;
      else rr[id] = 1;
    }

    console.log(j.length);
  }

  var items = Object.keys(rr).map(function (key) {
    return [key, rr[key]];
  });

  // Sort the array based on the second element
  items.sort(function (first, second) {
    return second[1] - first[1];
  });

  const dataPath2 = path.resolve(__dirname, "population.json");

  fs.writeFileSync(
    dataPath2,
    JSON.stringify(items.map((x) => parseInt(x[0]))),
    function (err) {
      console.log(err);
      process.exit();
    }
  );
}

_buildPopulation();
