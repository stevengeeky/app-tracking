#!/bin/env python

#find all lmax(n).mif and create products.json

import os
import glob
import json

files = []
#product = {"type"=>"soichih/neuro-mif/lmax", "files"=>[]}

for file in glob.glob("lmax*.mif"):
    files.append({"filename":file, "size":os.path.getsize(file)})

with open('products.json', 'w') as pfile:
    json.dump([{"type": "soichih/neuro-mif/lmax", "files": files}], pfile)

