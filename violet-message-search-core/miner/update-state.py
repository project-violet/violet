# This source code is a part of Project Violet.
# Copyright (C) 2021. violet-team. Licensed under the Apache-2.0 License.

import os
import sys

job_count = 20

ids = open("ids.txt", "r").read().split(',')
ids_len = len(ids)

cjob = []
summ = 0

for i in range(job_count):
    j = int(open("workspace/current_job" + str(i), "r").read().strip()) - 1
    cjob.append(j)
    summ += j

result = "# htext-miner-english (Second Engine)\n"
result += "\n"
result += "Everything doing here is automated.\n"
result += "\n"
result += "```\n"
result += "htext-miner\n"
result += "\n"
result += "total: " + str(summ) + "/" + str(ids_len) + \
    " (" + str(summ / ids_len * 100) + "%)" + "\n"
result += "\n"

for i in range(job_count):
    result += "job" + str(i) + ": " + str(cjob[i]) + "\n"

result += "```"

open("README.md", "w").write(result)
