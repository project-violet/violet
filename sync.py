# This source code is a part of project violet-server.
# Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

import sys
import os
import os.path
import time
from subprocess import Popen, PIPE
from datetime import datetime

def sync():
  #
  #   Sync (Low Performance Starting)
  #
  process = Popen(['./hsync', '-ls'])
  process.wait()

  #
  #   Compress
  #
  process = Popen(['7z', 'a', 'rawdata.7z', 'rawdata/*'], stdout=open(os.devnull, 'wb'))
  process.wait()
  process = Popen(['7z', 'a', 'rawdata-chinese.7z', 'rawdata-chinese/*'], stdout=open(os.devnull, 'wb'))
  process.wait()
  process = Popen(['7z', 'a', 'rawdata-english.7z', 'rawdata-english/*'], stdout=open(os.devnull, 'wb'))
  process.wait()
  process = Popen(['7z', 'a', 'rawdata-japanese.7z', 'rawdata-japanese/*'], stdout=open(os.devnull, 'wb'))
  process.wait()
  process = Popen(['7z', 'a', 'rawdata-korean.7z', 'rawdata-korean/*'], stdout=open(os.devnull, 'wb'))
  process.wait()

  #
  #   Upload
  #
  date = datetime.utcnow().strftime('%Y.%m.%d')
  process = Popen(['github-release',
    'upload', 
    '--owner=violet-dev',
    '--repo=db',
    '--tag=' + date,
    '--release-name="db' + date + '"',
    '--body=""',
    '--prerelease=false',
    '--token=',
    'rawdata.7z',
    'rawdata-chinese.7z',
    'rawdata-english.7z',
    'rawdata-japanese.7z',
    'rawdata-korean.7z'
  ])
  process.wait()

latest_sync_date = ''

while True:
  cur_date = datetime.utcnow().strftime('%Y.%m.%d')
  if latest_sync_date != cur_date:
    latest_sync_date = cur_date
    sync()
  # 1 hour
  time.sleep(60 * 60)