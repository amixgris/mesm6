#!/usr/bin/env python
# -*- encoding: utf-8 -*-
#
# Compile Madlen assembler source into object file.
# Invoke dispak simulator to run Madlen.
# Produce an output image in binary format:
#   filename.obj
#
# Leave twree imtermediate files:
#   filename.b6     -- task file for dispak simulator
#   filename.lst    -- listing generated by Madlen
#   filename.punch  -- punchcards of resulting object file
#
import sys, os, string, subprocess, struct

#
# Parse command line.
#
if len(sys.argv) < 2:
    print "Usage: madlen-to-obj.py filename.madlen"
    sys.exit(1)
input_name = sys.argv[1]
basename = os.path.splitext(input_name)[0]
#print "basename =", basename

#
# Open input file.
#
try:
    input_file = open(input_name)
except:
    print "%s: Cannot open input file" % input_name
    sys.exit(1)

#
# Read input file and generate a task file.
#
task_name = basename + ".b6"
task_file = open(task_name, "w")
task_file.write("""шифр 419999 зс5^
лен 67(2148)^
eeв1а3
*name %s
*punch
*assem
""" % basename)
for line in input_file.readlines():
    task_file.write(line.rstrip() + "\n")
task_file.write("""*end file
``````
еконец
""")
task_file.close()

#
# Run dispak simulator.
#
dispak = subprocess.Popen('dispak --punch=%s.punch %s.b6' % (basename, basename),
    shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

lst_file = open(basename + ".lst", "w")
nerrors = -1
for line in dispak.stdout.readlines():
    lst_file.write(line.rstrip() + "\n")

    # Find status: number of errors.
    line = line.decode('utf-8')
    if len(line) == 52 and line[23:45] == u"ЧИСЛО ОШИБ. ОПЕРАТОРОВ":
        nerrors = int(line[47:51])
        #print "nerrors =", nerrors
lst_file.close()

retval = dispak.wait()
#print "retval =", retval
if retval == 127:
    print "dispak: Command not found"
    lst_file.close()
    os.remove(basename + ".lst")
    sys.exit(1)
if retval != 0:
    print "dispak: Failed to invoke Madlen assembler"
    sys.exit(1)
if nerrors != 0:
    print "dispak: Madlen errors detected: see %s.lst for details" % basename
    sys.exit(1)

#
# Open the punch file.
#
try:
    punch_file = open(basename + ".punch")
except:
    print "%s.punch: Cannot open punch file" % basename
    sys.exit(1)

#
# Extract one column of 12 bits from the punchcard.
#
def get12bits(card, x):
    word = 0
    for y in range(12):
        bit = card[y][x]
        if bit == 'O':
            word |= 1 << y
    return word

#
# Generate obj file.
#
obj_file = open(basename + ".obj", "w")
obj_file.write("BESM6\0")
for cardno in range(1024):
    card = {}
    card[0] = punch_file.readline()
    if not card[0]:
        break
    for i in range(1,13):
        card[i] = punch_file.readline()
    if not card[12]:
        print "%s: Bad file format" % input_name
        sys.exit(1)
    #print card[0],
    if cardno == 0:
        # Skip first card.
        continue

    for x in [4, 8, 13, 17, 22, 26, 31, 35, 40, 44, 49, 53, 58, 62, 67, 71]:
        a = get12bits(card, x)
        b = get12bits(card, x+1)
        c = get12bits(card, x+2)
        d = get12bits(card, x+3)
        #print "%04o %04o %04o %04o" % (a, b, c, d)

        f = d & 0xff
        e = (d >> 8) | (c << 4 & 0xff)
        d = c >> 4
        c = b & 0xff
        b = (b >> 8) | (a << 4 & 0xff)
        a = a >> 4
        #print "%02x %02x %02x %02x %02x %02x" % (a, b, c, d, e, f)
        obj_file.write(struct.pack("BBBBBB", a, b, c, d, e, f))

    if card[0][3] == 'O':
        # Last card.
        break

obj_file.close()

print "File %s succesfully compiled into %s.obj" % (input_name, basename)
