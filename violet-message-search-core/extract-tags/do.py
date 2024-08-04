import sqlite3
import json

conn = sqlite3.connect("data.db")

cur = conn.cursor()
cur.execute("SELECT * FROM HitomiColumnModel WHERE Language='korean'");
rows = cur.fetchall()

typemap = {}
typecount = 0

for row in rows:
  typee = row[2]
  if typee == None:
    continue
  typee = typee.replace(' ', '_')
  if not typee in typemap:
    typemap[typee] = typecount
    typecount += 1

tagmap = {}
tagcount = 0

for row in rows:
  tags: str = row[-8]
  if tags == None:
    continue
  tags = tags.replace(' ', '_')
  for tag in list(filter(lambda x: x != '', tags.split('|'))):
    if not tag in tagmap:
      tagmap[tag] = tagcount
      tagcount += 1

result = []

for row in rows:
  articleid = row[-1]
  if row[2] == None:
    typee = -1
  else:
    typee = typemap[row[2].replace(' ', '_')]
  tags = row[-8]
  rtags = []
  if tags != None:
    for tag in list(filter(lambda x: x != '', tags.split('|'))):
      rtags.append(tagmap[tag.replace(' ', '_')])
  result.append({'id': articleid, 'type': typee, 'tags': rtags})

conn.close()

with open('taginfo.json', 'w') as f:
  f.write(json.dumps(tagmap, separators=(',', ':')))
with open('typeinfo.json', 'w') as f:
  f.write(json.dumps(typemap, separators=(',', ':')))
with open('db.json', 'w') as f:
  f.write(json.dumps(result, separators=(',', ':')))
