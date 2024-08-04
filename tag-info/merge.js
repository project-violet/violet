//===----------------------------------------------------------------------===//
//
//                       Violet Tag Info Program
//
//===----------------------------------------------------------------------===//
//
//  Copyright (C) 2021. violet-team. All Rights Reserved.
//
//===----------------------------------------------------------------------===//

const path = require('path');
const fs = require('fs');

const d_kor_character = require('./dict/kor-character');
const d_kor_series = require('./dict/kor-series');
const d_kor_tag = require('./dict/kor-tag');

var result = {};

function insert(dict, prefix) {
    Object.keys(dict).forEach(function(key) {
        if (dict[key] != '')
            result[prefix+':'+key] = dict[key];
    });
}

insert(d_kor_character, 'character');
insert(d_kor_series, 'series');
insert(d_kor_tag, 'tag');

const dataPath = path.resolve(
    __dirname, 'result-korean-merge.json');

fs.writeFile(dataPath, JSON.stringify(result, null, 4), function(err) {
  console.log(err);
});