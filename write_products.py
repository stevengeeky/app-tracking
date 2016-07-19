#!/bin/env python

#find all lmax(n).mif and create products.json

import os
import glob
import json

types = {}

for filename in glob.glob("output.*.tck"):
    tokens = filename.split(".")
    type=tokens[1]
    lmax=int(tokens[2])
    if not type in types:
        types[type] = {}

    size = os.path.getsize(filename)
    types[type][lmax] = {"filename":filename, "size":size}

with open('products.json', 'w') as pfile:
    json.dump([{"type": "soichih/neuro-mif/tracking", "types": types}], pfile)

