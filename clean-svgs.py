#!/usr/bin/python3
#Remove rubbish from svg files
import glob
import xml.etree.ElementTree as et
import multiprocessing as mp

buildDir = "assets/svg"
et = et.ElementTree()
targetNamespaces = ["{http://www.inkscape.org/namespaces/inkscape}"]

def cleanFile(inputFile):
  #Find metadata tag in document
  root = et.parse(inputFile)
  metadata = root.find("{http://www.w3.org/2000/svg}metadata")
  fileChanged = False

  #Remove if present
  if metadata != None:
    root.remove(metadata)
    fileChanged = True

  #Find all attributes matching namespaces to remove
  delKeys = []
  for attribute in root.attrib:
    for namespace in targetNamespaces:
      if namespace in attribute:
        delKeys.append(attribute)

  if delKeys == [] and fileChanged == False:
    return 0 #File not changed

  #Remove the marked keys
  for key in delKeys:
    root.attrib.pop(key)

  et.write(inputFile)
  return 1 #File changed

svgFiles = glob.glob(f"{buildDir}/*/*.svg")
if svgFiles == []:
  print("No svg files found to clean")
  exit(1)

#Spread files between available cores
with mp.Pool(mp.cpu_count()) as pool:
  result = pool.map(cleanFile, svgFiles)

print(f"Cleaned {result.count(1)} file(s)")
