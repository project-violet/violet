//===----------------------------------------------------------------------===//
//
//                   Violet API Server Population Eggreator
//
//===----------------------------------------------------------------------===//
//
//  Copyright (C) 2021. violet-team. All Rights Reserved.
//
//===----------------------------------------------------------------------===//

const a_syncdatabase = require('./api/syncdatabase');

const path = require('path');
const fs = require('fs');

const d_kor_character = require('./dict/kor-character');
const d_kor_series = require('./dict/kor-series');

var result = {};

function insert(dict) {
  Object.keys(dict).forEach(function(key) {
    if (dict[key] != '') result[key] = dict[key];
  });
}

insert(d_kor_character);
insert(d_kor_series);

async function _buildPopulation() {
  const conn = a_syncdatabase();
  const data = conn.query(`with search_query as 
      (
        select c.Id
        from
          eharticles_characters as a
          right join eharticles_characters_junction as b on a.Id=b.Character
          right join eharticles as c on c.Id=b.Article
        -- where c.Language="korean"
        order by b.Article desc
      )
      select a.CharacterName, a.c as Count, 
        SUBSTRING_INDEX(GROUP_CONCAT(CONCAT(b.Name, '(', a.cc, ')') ORDER BY a.cc DESC SEPARATOR ','), ',', 5) as MAIN_TAGS 
        from (
        select a.CharacterName, count(b.Series) as cc, b.Series, a.c from (
          select * from (
            select b.Name as CharacterName, b.Id, a.c from (
              select a.Character, count(a.Character) as c
              from search_query as sq
              left join eharticles_characters_junction as a on sq.Id=a.Article 
              group by a.Character 
              order by c
            ) as a left join eharticles_characters as b
            on a.Character=b.Id
            where b.Id<>0
            order by a.c desc
          ) as a left join eharticles_characters_junction as b
          on a.Id=b.Character
        ) as a left join eharticles_series_junction as b
        on a.Article=b.Article
        group by a.CharacterName, b.Series
        order by cc desc
      ) as a left join eharticles_series as b on a.Series=b.Id
      group by a.CharacterName
      order by a.c desc`);
  const dataPath = path.resolve(__dirname, 'series-character-matcher.json');

  console.log(data.length);

  // {"CharacterName":"teitoku","Count":29442,"MAIN_TAGS":"kantai
  // collection(11627)..."}
  var seriesMap = {};
  data.map(function(e) {
    if (e['MAIN_TAGS'] == null) return;
    var series = e['MAIN_TAGS'].split('(')[0];
    if (series in result) series = result[series];
    if (!(series in seriesMap)) seriesMap[series] = [];
    if (e['CharacterName'] in result)
    seriesMap[series].push(
        result[e['CharacterName']]);
        else
        seriesMap[series].push(e['CharacterName']);

  });

  fs.writeFile(dataPath, JSON.stringify(seriesMap), function(err) {
    console.log(err);
    process.exit();
  });
}

_buildPopulation();