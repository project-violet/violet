
const path = require('path');
const fs = require('fs');

function test(file) {
    var json = JSON.parse(fs.readFileSync(file).toString());
    var total = 0;
    var processed = 0;
    Object.keys(json).forEach((x) => {
        total += 1;
        if (json[x] != '') {
            processed += 1;
        }
    });

    return processed * 1.0 / total * 100;
}

console.log('character: ' + test('result-korean-character.json').toFixed(2) + ' %');
console.log('sereis: ' + test('result-korean-series.json').toFixed(2) + ' %');
console.log('tag: ' + test('result-korean-tag.json').toFixed(2) + ' %');