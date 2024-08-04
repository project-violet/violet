# This source code is a part of Project Violet.
# Copyright (C) 2021. violet-team. Licensed under the Apache-2.0 License.

import os
import sys

job_count = 20
job_id = int(sys.argv[1])

read_id_index = int(open("workspace/current_job" + str(job_id), "r").read().strip()) - 1
target_id_index = read_id_index * job_count + job_id

ids = open("ids.txt", "r").read().split(',')
target_id = ids[len(ids) - target_id_index - 1].strip()

artifact_url = sys.argv[2]

if not os.path.isfile("workspace/history-" + str(job_id) + ".txt"):
  open("workspace/history-" + str(job_id) + ".txt", "w").close()

open("workspace/history-" + str(job_id) + ".txt", "a").write(str(target_id)+"\n")
