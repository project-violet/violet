import sys

job_id = int(sys.argv[1])

read_id_index = int(open("workspace/current_job" +
                    str(job_id), "r").read().strip())

open("workspace/current_job" + str(job_id), "w").write(str(read_id_index + 1))