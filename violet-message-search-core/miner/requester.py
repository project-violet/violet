# This source code is a part of project violet-server.
# Copyright (C) 2021. violet-team. Licensed under the MIT Licence.

import time
from urllib import request

while True:
  res = request.urlopen('http://127.0.0.1:8864/contains/').read()
  # 1 min
  time.sleep(60)