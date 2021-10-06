# This source code is a part of Project Violet.
# Copyright (C) 2021.violet-team. Licensed under the Apache-2.0 License.

import sys
import os
import os.path
import re

target = 'ios'

def process_dart(path):
    f = open(path, 'r')
    w = []
    nl = False
    op = False
    for line in f.readlines():
        if '//' in line:
            annote = re.split(r': |, | ',line.split('//')[-1].strip())

            if not annote[0].startswith('@dependent'):
                if nl or op:
                    nl = False
                else:
                    w.append(line)
                continue

            if annote[1] == target:
                w.append(line)
                continue

            if len(annote) == 2:
                continue

            if annote[2] == '=>':
                nl = True
                continue

            if annote[2] == '[':
                op = True
                continue

            if annote[2] == ']':
                op = False
                continue
        else:
            if nl or op:
                nl = False
            else:
                w.append(line)
    f.close()
    f = open(path, 'w+')
    f.writelines(w)
    f.close()

def process_yaml(path):
    f = open(path, 'r')
    w = []
    nl = False
    op = False
    for line in f.readlines():
        if '#' in line:
            annote = re.split(r': |, | ', line.split('#')[-1].strip())

            if not annote[0].startswith('@dependent'):
                if nl or op:
                    nl = False
                else:
                    w.append(line)
                continue

            if annote[1] == target:
                w.append(line)
                continue

            if len(annote) == 2:
                continue

            if annote[2] == '=>':
                nl = True
                continue

            if annote[2] == '[':
                op = True
                continue

            if annote[2] == ']':
                op = False
                continue
        else:
            if nl or op:
                nl = False
            else:
                w.append(line)
    f.close()
    f = open(path, 'w+')
    f.writelines(w)
    f.close()

def create_dummy_valid(path):
    f = open(path, 'w')
    f.writelines(['String getValid(foo) {return foo;}'])
    f.close()

for root, subdirs, files in os.walk('./'):
    for filename in files:
        if filename.endswith(".dart"): 
            process_dart(root + '/' + filename)
        elif filename.endswith(".yaml"):
            process_yaml(root + '/' +  filename)

# create_dummy_valid('./lib/server/salt.dart')
# create_dummy_valid('./lib/server/wsalt.dart')