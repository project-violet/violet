import json
from os import listdir
from os.path import isfile, join

localepath = '../assets/locale'
localefiles = [f for f in listdir(localepath) if isfile(join(localepath, f))]

def readjson(fn):
    with open(fn, encoding='utf-8') as jf:
        return json.load(jf)

def extractKeys(jdata):
    return list(jdata.keys())

def extractKeysToDict(jdata):
    kdict = {string : 1 for string in extractKeys(jdata)}
    return kdict

# source file
srcfile = localepath + '/' + 'ko.json'
srcraw = readjson(srcfile)
srcdata = extractKeys(srcraw)

def checkValidTarget(tarfile):
    tarraw = readjson(tarfile)
    tardata = extractKeysToDict(tarraw)

    for srckey in srcdata:
        if srckey not in tardata:
            print(srckey +' is not found')
            return False

    return True


for fn in localefiles:
    tarfile = localepath + '/' + fn
    if srcfile == tarfile:
        continue

    if checkValidTarget(tarfile) == True:
        print('[Pass] ' + fn)
    else:
        print('[Fail] ' + fn)