#!/usr/bin/python

import fileinput
import json
import sys

for line in fileinput.input():
    if "write-file" in line:
        sys.stdout.write('skipped')
    else:
        sys.stdout.write(line)

sys.stdout.write('\n')
