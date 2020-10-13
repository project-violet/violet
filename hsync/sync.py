# This source code is a part of project violet-server.
# Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

import sys
import os
import os.path
import time
import shutil
from subprocess import Popen, PIPE
from datetime import datetime

token = 'faketoken'
dbmetapath = '/home/violet.dev.master/violet-server/frontend/build/version.txt'

def sync():
  #
  #   Sync (Low Performance Starting)
  #
  shutil.rmtree('chunk', ignore_errors=True)
  process = Popen(['./hsync', '-ls', '--sync-only'])
  process.wait()

def upload_chunk():
  # donot use utcnow()
  timestamp = str(int(datetime.now().timestamp()))
  filename = os.listdir('chunk')[0]
  chunkfile = 'chunk/' + filename
  size = os.path.getsize(chunkfile)

  process = Popen(['github-release',
    'upload', 
    '--owner=violet-dev',
    '--repo=chunk',
    '--tag=' + timestamp,
    '--release-name=chunk ' + timestamp + '',
    '--body=""',
    '--prerelease=false',
    '--token=' + token,
    chunkfile,
  ])
  process.wait()

  url = 'https://github.com/violet-dev/chunk/releases/download/'+timestamp+'/'+filename
  with open(dbmetapath, "a") as myfile:
    myfile.write('chunk ' + timestamp + ' ' + url + ' ' + str(size) + '\n')
  
def release():
  #
  #   Create database
  #
  process = Popen(['./hsync', '-lc'])
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
    '--release-name=db ' + date + '',
    '--body=""',
    '--prerelease=false',
    '--token=' + token,
    'rawdata.7z',
    'rawdata-chinese.7z',
    'rawdata-english.7z',
    'rawdata-japanese.7z',
    'rawdata-korean.7z'
  ])
  process.wait()

  timestamp = str(int(datetime.now().timestamp()))
  url = 'https://github.com/violet-dev/db/releases/download/'+date+'/rawdata'
  with open(dbmetapath, "a") as myfile:
    myfile.write('db ' + timestamp + ' ' + url + '\n')

def remove_exists(path):
  if os.path.exists(path):
    os.remove(path)

def clean():
  shutil.rmtree('rawdata', ignore_errors=True)
  shutil.rmtree('rawdata-chinese', ignore_errors=True)
  shutil.rmtree('rawdata-english', ignore_errors=True)
  shutil.rmtree('rawdata-japanese', ignore_errors=True)
  shutil.rmtree('rawdata-korean', ignore_errors=True)
  
  remove_exists('rawdata.7z')
  remove_exists('rawdata-chinese.7z')
  remove_exists('rawdata-english.7z')
  remove_exists('rawdata-japanese.7z')
  remove_exists('rawdata-korean.7z')

latest_sync_date = ''

while True:
  sync()
  upload_chunk()
  cur_date = datetime.utcnow().strftime('%Y.%m.%d')
  if latest_sync_date != cur_date:
    latest_sync_date = cur_date
    clean()
    release()
  # 1 hour
  time.sleep(60 * 60)