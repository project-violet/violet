# This source code is a part of Project Violet.
# Copyright (C) 2021. violet-team. Licensed under the Apache-2.0 License.

import sys
import os
from os import listdir
import os.path
from os.path import isfile, join
import re

sched_slot_count = 20


def create_sched(id):
    f = open('sched_frame.yml', 'r')
    w = []

    for line in f.readlines():
        w.append(line.replace("%id%", id))

    f.close()
    f = open('.github/workflows/sched' + id + '.yml', 'w+')
    f.writelines(w)
    f.close()


for i in range(sched_slot_count):
    create_sched(str(i))


def sched_jobs():
    ids = open("ids.txt", "r").read().split(',')
    results = map(lambda x: x.split('.')[0], [
                  f for f in listdir("result") if isfile(join("result", f))])
    histories = set(map(int, results))

    print(histories)

    def create_job(id):
        cnt = 0
        while True:
            ptr = len(ids) - (cnt * sched_slot_count + id) - 1
            if not int(ids[ptr]) in histories:
                print(int(ids[ptr]))
                f = open('workspace/current_job' + str(id), 'w')
                f.write(str(cnt))
                f.close()
                break
            cnt += 1

    for i in range(sched_slot_count):
        create_job(i)


# sched_jobs()


def init_jobs():
    for i in range(sched_slot_count):
        with open('workspace/current_job' + str(i), 'w') as f:
            f.write(str(0))


# init_jobs()
