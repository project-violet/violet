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

const _tagList = [
  ['eharticles_tags', 'Tag'],
  ['eharticles_series', 'Series'],
  ['eharticles_characters', 'Character'],
];

async function _buildSortWithCount(dbPrefix) {
  const conn = a_syncdatabase();
  const data = conn.query(
      `
select a.Name from (select b.Name, count(*) as c 
from ` +
      dbPrefix[0] + '_junction' +
      ' as a left join ' + dbPrefix[0] + ' as b on a.' + dbPrefix[1] +
      '=b.Id group by a.' + dbPrefix[1] + ' order by c desc) as a');
  const dataPath =
      path.resolve(__dirname, 'result-' + dbPrefix[1].toLowerCase() + '.json');

  console.log(data.length);

  fs.writeFile(
      dataPath, JSON.stringify(data.map(x => x.Name), null, 4), function(err) {
        console.log(err);
      });
}

async function _buildSortWithNewest(dbPrefix) {
    const conn = a_syncdatabase();
    const data = conn.query(
        'select Name from ' + dbPrefix[0] + ' order by Id desc');
    const dataPath =
        path.resolve(__dirname, 'result-newest-' + dbPrefix[1].toLowerCase() + '.json');
  
    console.log(data.length);
  
    fs.writeFile(
        dataPath, JSON.stringify(data.map(x => x.Name), null, 4), function(err) {
          console.log(err);
        });
  }
  

async function _test() {
  for (var i = 0; i < _tagList.length; i++) {
    await _buildSortWithCount(_tagList[i]);
    await _buildSortWithNewest(_tagList[i]);
  }
}

_test();