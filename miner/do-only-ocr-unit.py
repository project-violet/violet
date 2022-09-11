# This source code is a part of Project Violet.
# Copyright (C) 2022. violet-team. Licensed under the Apache-2.0 License.

from PIL import ImageFile
import torch
ImageFile.LOAD_TRUNCATED_IMAGES = True

import easyocr
from PIL import Image
import os
from os import listdir
from subprocess import Popen, PIPE
from os.path import isfile, join
import sys
ImageFile.LOAD_TRUNCATED_IMAGES = True

target_id = "999999999"

onlyfiles = [f for f in listdir('image') if isfile(join('image', f))]
onlyfiles = sorted(onlyfiles)

page_count = 0
outputs = target_id + "\n" + str(len(onlyfiles)) + "\n"

print(torch.cuda.is_available() )

for file in onlyfiles:
    fs = join ('image', file)

    if not file.endswith('jpg'):
        continue

    # im = Image.open(fs).convert("RGB")
    # im.save(fs + '.jpg', "jpeg")

    reader = easyocr.Reader(['ko'])
    result = reader.readtext(fs)
    
    page_count += 1
    outputs += str(result)
    outputs += "\n"
    
    print ("progress: " + str(page_count) + "/" + str(len(onlyfiles)))
    
if not os.path.exists('result'):
    os.makedirs('result')

# f = open('result/' + target_id + ".txt", "w")
# f.write(outputs)
# f.close()
 
print(outputs)