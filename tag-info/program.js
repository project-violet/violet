//===----------------------------------------------------------------------===//
//
//                       Violet Tag Info Program
//
//===----------------------------------------------------------------------===//
//
//  Copyright (C) 2021. violet-team. All Rights Reserved.
//
//===----------------------------------------------------------------------===//

const a_syncdatabase = require('./api/syncdatabase');

const path = require('path');
const fs = require('fs');

const d_kor_series = require('./dict/kor-series');
const d_kor_tag = require('./dict/kor-tag');
const d_kor_character = require('./dict/kor-character');

const _tagList = [
  ['eharticles_tags', 'Tag'],
  ['eharticles_series', 'Series'],
  ['eharticles_characters', 'Character'],
];

function _transKor(tar) {
  if (tar in d_kor_series) return d_kor_series[tar];
  if (tar in d_kor_tag) return d_kor_tag[tar];
  if (tar in d_kor_character) return d_kor_character[tar];
  return '';
}

async function _buildSortWithCountKorean(dbPrefix) {
  const conn = a_syncdatabase();
  const data = conn.query(
      `
select a.Name from (select b.Name, count(*) as c 
from ` +
      dbPrefix[0] + '_junction' +
      ' as a left join ' + dbPrefix[0] + ' as b on a.' + dbPrefix[1] +
      '=b.Id group by a.' + dbPrefix[1] + ' order by c desc) as a');
  const dataPath =
      path.resolve(__dirname, 'result-korean-' + dbPrefix[1].toLowerCase() + '.json');

  console.log(data.length);

  var result = {};
  data.forEach(x => result[x.Name] = _transKor(x.Name));

  fs.writeFile(dataPath, JSON.stringify(result, null, 4), function(err) {
    console.log(err);
  });
}

async function _buildSortWithNewestKorean(dbPrefix) {
  const conn = a_syncdatabase();
  const data =
      conn.query('select Name from ' + dbPrefix[0] + ' order by Id desc');
  const dataPath = path.resolve(
      __dirname, 'result-korean-newest-' + dbPrefix[1].toLowerCase() + '.json');

  console.log(data.length);

  var result = {};
  data.forEach(x => result[x.Name] = _transKor(x.Name));

  fs.writeFile(dataPath, JSON.stringify(result, null, 4), function(err) {
    console.log(err);
  });
}

async function _test() {
  //await _buildSortWithCountKorean(_tagList[1]);
  for (var i = 0; i < _tagList.length; i++) {
    await _buildSortWithCountKorean(_tagList[i]);
    // await _buildSortWithNewest(_tagList[i]);
  }
}

_test();