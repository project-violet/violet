# This source code is a part of Project Violet.
# Copyright (C) 2021. violet-team. Licensed under the Apache-2.0 License.

import sys
import os
import math
from os import listdir
import os.path
from os.path import isfile, join
import re
import json

f = open('nohup.out', 'r', encoding="UTF-8")
lines = f.readlines()
f.close()

contains = {}
similar = {}

for line in lines:
    if not line.startswith('('):
        continue

    data = line.split(')', 1)[1].strip().rsplit('|', 1)[0].strip()

    sc = data.split(':')[0].strip()
    msg = data.split(':',1)[1].strip()

    if sc == 'contains':
        if not msg in contains:
            contains[msg] = 0
        contains[msg] += 1
    elif sc == 'similar':
        if not msg in similar:
            similar[msg] = 0
        similar[msg] += 1
    else:
        print('error')

def save(name, what):
    what = dict(sorted(what.items(), key=lambda item: -item[1]))
    with open(name, 'w', encoding='UTF-8') as file:
        file.write(json.dumps(what, ensure_ascii=False, indent=4))

    print(json.dumps(what, ensure_ascii=False, indent=4))

save('contains.json', contains)
save('similar.json', similar)