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

drop_threshold = 0.1
drop_min_distx = 30.0
drop_min_disty = 80.0

def parse(page):
    ptr = 1
    plen = len(page)

    items = []

    while True:
        if ptr == plen:
            break

        if page[ptr] == ']':
            break
        while page[ptr] == ' ':
            ptr += 1

        item = ''
        safez = False
        while True:
            if page[ptr] == ')':
                ptr += 1
                break
            if page[ptr] == '(':
                ptr += 1

            if page[ptr] == "'":
                item += '"'
                ptr += 1
                while True:
                    if page[ptr] == "'":
                        item += '"'
                        ptr += 1
                        break
                    if page[ptr] == '"':
                        item += '\\' + page[ptr]
                        ptr += 1
                        continue
                    if page[ptr] == '\\':
                        ptr += 1
                        item += page[ptr]
                    item += page[ptr]
                    ptr += 1
            elif page[ptr] == '"':
                item += '"'
                ptr += 1
                while True:
                    if page[ptr] == '"':
                        item += '"'
                        ptr += 1
                        break
                    if page[ptr] == '\\':
                        item += page[ptr]
                        ptr += 1
                    item += page[ptr]
                    ptr += 1
            else:
                item += page[ptr]
                ptr += 1

        items.append(json.loads('[' + item + ']'))

        while page[ptr] == ' ':
            ptr += 1
        if page[ptr] == ',':
            ptr += 1
        while page[ptr] == ' ':
            ptr += 1

        ptr += 1
    
    return items

def sentence_correction(sentence):
    return sentence
    
def merge(filename, onlyText=False):
    f = open(filename, 'r', encoding="UTF-8")
    data = f.readlines()
    f.close()

    dlen = int(data[1].strip())

    def merge_by_dist(page, onlyText):
        group = list(range(len(page)))

        def calc_dist(item1, item2):
            (l11,l12,l21,l22,l31,l32,l41,l42)= \
                (item1[0][0][0],item1[0][0][1],item1[0][1][0],item1[0][1][1], \
                 item1[0][2][0],item1[0][2][1],item1[0][3][0],item1[0][3][1])
            (r11,r12,r21,r22,r31,r32,r41,r42)= \
                (item2[0][0][0],item2[0][0][1],item2[0][1][0],item2[0][1][1], \
                 item2[0][2][0],item2[0][2][1],item2[0][3][0],item2[0][3][1])

            mlx = (l11 + l21 + l31 + l41) / 4
            mly = (l12 + l22 + l32 + l42) / 4
            mrx = (r11 + r21 + r31 + r41) / 4
            mry = (r12 + r22 + r32 + r42) / 4

            return abs(mlx-mrx), abs(mly-mry)

        for i in range(1,len(page)):
            min_distx = 99999.0
            min_disty = 99999.0
            min_index = i
            for j in range(i):
                distx, disty = calc_dist(page[i], page[j])
                if distx < drop_min_distx and disty < drop_min_disty:
                    if distx < min_distx and disty < min_disty:
                        min_distx = distx
                        min_disty = disty
                        min_index = j

            group[i] = group[min_index]

        grouping = [''] * len(page)
        groupingc = [0] * len(page)
        groupingw = [0] * len(page)
        for i in range(len(page)):
            if page[i][2] > drop_threshold:
                grouping[group[i]] += ' '+page[i][1]
                groupingc[group[i]] += 1
                groupingw[group[i]] += page[i][2]
        for i in range(len(page)):
            grouping[i] = sentence_correction(grouping[i].strip())
        result = []
        for i in range(len(page)):
            if grouping[i] != '':
                if onlyText:
                    result.append(grouping[i])
                else:
                    result.append((grouping[group[i]],groupingw[group[i]] / groupingc[group[i]]))
        return result

    pages = []
    for i in range(dlen):
        page = data[i+2].strip()
        items = parse(page)

        # grouping
        group_info = merge_by_dist(items, onlyText)
        if onlyText:
            pages.append(group_info)
        else:
            pages.append({'page':i,'content':group_info})

    return json.dumps(pages, ensure_ascii=False, indent=4)


files = [f for f in listdir("result") if isfile(join("result", f))]
for file in files:
    if os.path.isfile('merged/' + file.split('.')[0] + '-merged.txt'):
        continue
    open('merged/' + file.split('.')[0] + '-merged.txt', 'w').write(merge(join("result", file)))
    print(file)