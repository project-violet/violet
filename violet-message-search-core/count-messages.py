import json
from os import listdir
from os.path import isfile, join
import sqlite3

conn = sqlite3.connect("db.db")
cur = conn.cursor()
conn.execute(''
  'CREATE TABLE messages(id INTEGER, '
  'ArticleId INTEGER, Page INTEGER, Message TEXT, MessageRaw TEXT, '
  'Score DOUBLE, Rectangle TEXT)')

mypath = 'G:\\Dev2\\violet-message-search\\cache-raw'
onlyfiles = [f for f in listdir(mypath) if isfile(join(mypath, f))]

count = 0
status = 0
result = 0
for f in onlyfiles:
  status += 1
  with open(join(mypath, f), encoding='utf-8') as fn:
    j = json.load(fn)
    result += len(j)
    for m in j:
      count += 1
      cur.executemany(
        'INSERT INTO messages VALUES (?, ?, ?, ?, ?, ?, ?)',
        [(count, m['ArticleId'], m['Page'], m['Message'], m['MessageRaw'], m['Score'], json.dumps(m['Rectangle']))])
      
    conn.commit()
        
    print('%d/%d' % (status, len(onlyfiles)))