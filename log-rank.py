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

contains = {}
similar = {}

def process(filename):
    f = open(filename, 'r', encoding="UTF-8")
    lines = f.readlines()
    f.close()

    for line in lines:
        if line.startswith('('):
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
        elif line.split(':')[0] == 'contains' or line.split(':')[0] == 'similar':
            sc = line.split(':')[0].strip()
            msg = line.split(':',1)[1].strip()

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

process('nohup-legacy8.out')
process('nohup-legacy7.out')
process('nohup-legacy6.out')
process('nohup-legacy5.out')
process('nohup-legacy4.out')
process('nohup-legacy3.out')
process('nohup-legacy.out')
process('nohup.out')

def apply_blacklist():
    f = open('blacklist.txt', 'r', encoding="UTF-8")
    lines = f.readlines()
    f.close()

    for line in lines:
        # del contains[line.strip()]
        # del similar[line.strip()]
        contains.pop(line.strip(), None)
        similar.pop(line.strip(), None)

apply_blacklist()

def save(name, what):
    what = dict(sorted(what.items(), key=lambda item: -item[1]))
    with open(name, 'w', encoding='UTF-8') as file:
        file.write(json.dumps(what, ensure_ascii=False, indent=4))

    # print(json.dumps(what, ensure_ascii=False, indent=4))

save('contains.json', contains)
save('similar.json', similar)

def save_sorted_with_alphabet():
    with open('SORT.md', 'w', encoding='UTF-8') as file:
        c = dict(sorted(contains.items(), key=lambda item: item[0]))
        s = dict(sorted(similar.items(), key=lambda item: item[0]))

        file.write('# Log Rank (Sort)\n[Contains](#Contains)\n[Similar](#Similar)\n## Contains\n```\n')
        file.write(json.dumps(c, ensure_ascii=False, indent=4))
        file.write('\n```\n## Similar\n```\n')
        file.write(json.dumps(s, ensure_ascii=False, indent=4))
        file.write('\n```')

save_sorted_with_alphabet()

def create_readme():
    with open('README.md', 'w', encoding='UTF-8') as file:
        c = dict(sorted(contains.items(), key=lambda item: -item[1]))
        s = dict(sorted(similar.items(), key=lambda item: -item[1]))

        file.write('# Log Rank\n[Contains](#Contains)\n[Similar](#Similar)\n## Contains\n```\n')
        file.write(json.dumps(c, ensure_ascii=False, indent=4))
        file.write('\n```\n## Similar\n```\n')
        file.write(json.dumps(s, ensure_ascii=False, indent=4))
        file.write('\n```')

create_readme()

def save_sorted_with_alphabet_combine():
    with open('SORT-COMBINE.md', 'w', encoding='UTF-8') as file:
        combine = contains.copy()
        
        for k,v in similar.items():
            if k in combine:
                combine[k] += v
            else:
                combine[k] = v

        c = dict(sorted(combine.items(), key=lambda item: item[0]))

        file.write('# Log Rank (Sort-Combine)\n## Combine\n```\n')
        file.write(json.dumps(c, ensure_ascii=False, indent=4))
        file.write('\n```')

def save_sorted_with_alphabet_combine_json():
    with open('SORT-COMBINE.json', 'w', encoding='UTF-8') as file:
        combine = contains.copy()
        
        for k,v in similar.items():
            if k in combine:
                combine[k] += v
            else:
                combine[k] = v

        c = dict(sorted(combine.items(), key=lambda item: item[0]))

        file.write(json.dumps(c, ensure_ascii=False))

save_sorted_with_alphabet_combine()
save_sorted_with_alphabet_combine_json()

def save_sorted_with_length_combine():
    with open('SORT-LEN-COMBINE.md', 'w', encoding='UTF-8') as file:
        combine = contains.copy()
        
        for k,v in similar.items():
            if k in combine:
                combine[k] += v
            else:
                combine[k] = v

        c = dict(sorted(combine.items(), key=lambda item: -len(item[0])))

        file.write('# Log Rank (Sort Length)\n## Combine\n```\n')
        file.write(json.dumps(c, ensure_ascii=False, indent=4))
        file.write('\n```')

save_sorted_with_length_combine()
