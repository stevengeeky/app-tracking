#!/bin/env python

#find all lmax(n).mif and create products.json

import os
import glob
import json

tracks = [] 
#product = {"type"=>"soichih/neuro-mif/lmax", "files"=>[]}

for filename in glob.glob("output.*.tck"):
    size = os.path.getsize(filename)
    #files.append({"filename":file, "size":os.path.getsize(file)})
    tokens = filename.split(".")
    #['output', '5', 'SD_PROB', '4', 'tck']
    print tokens
    track=int(tokens[1])
    type=tokens[2]
    lmax=int(tokens[3])

    while len(tracks) <= track:
        tracks.append({})

    if not type in tracks[track]:
        tracks[track][type] = {}

    tracks[track][type][lmax] = {"filename":filename, "size":size}

with open('products.json', 'w') as pfile:
    json.dump([{"type": "soichih/neuro-mif/tracking", "tracks": tracks}], pfile)

