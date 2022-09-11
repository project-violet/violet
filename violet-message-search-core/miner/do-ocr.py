import sys
from os.path import isfile, join
from subprocess import Popen, PIPE
from os import listdir
import os
from PIL import Image
import easyocr
from PIL import ImageFile
ImageFile.LOAD_TRUNCATED_IMAGES = True

ImageFile.LOAD_TRUNCATED_IMAGES = True

job_count = 20
job_id = int(sys.argv[1])

job_index = int(open("workspace/current_job" +
                     str(job_id), "r").read().strip()) - 1

read_id_index = job_index
target_id_index = job_index * job_count + job_id

ids = open("ids.txt", "r").read().split(',')
target_id = ids[len(ids) - target_id_index - 1].strip()

os.environ["CURRENTID"] = target_id
os.putenv("CURRENTID", target_id)

process = Popen(['gallery-dl', '-D', './image', '-f',
                '{num}.{extension}', 'https://hitomi.la/galleries/' + target_id + '.html'])
process.wait()

if not os.path.isdir('image'):
    exit()

onlyfiles = [f for f in listdir('image') if isfile(join('image', f))]
onlyfiles = sorted(onlyfiles)

page_count = 0
outputs = target_id + "\n" + str(len(onlyfiles)) + "\n"

if len(onlyfiles) > 300:
    exit()

for file in onlyfiles:
    fs = join('image', file)

    im = Image.open(fs).convert("RGB")
    im.save(fs + '.jpg', "jpeg")

    reader = easyocr.Reader(['en'], gpu=False)
    result = reader.readtext(fs + '.jpg')

    page_count += 1
    outputs += str(result)
    outputs += "\n"

    print("progress: " + str(page_count) + "/" + str(len(onlyfiles)))

if not os.path.exists('result'):
    os.makedirs('result')

f = open('result/' + target_id + ".txt", "w")
f.write(outputs)
f.close()
