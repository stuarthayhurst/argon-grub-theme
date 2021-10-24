#!/usr/bin/python3
import sys, subprocess, os

def getCommandExitCode(command):
  return subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode

def getAssetResolutionDir(resolution):
  convertDict = {
    "32": 37,
    "48": 56,
    "64": 74
  }
  return int(convertDict[str(resolution)])

#Generates the given icon for all required resolutions
def generateIcon(inputFile, iconType, iconResolutions):
  #Generate output file path by swapping to a png
  outputFile = inputFile.replace(".svg", ".png")
  outputFile = outputFile.replace("svg/", "")
  outputFile = outputFile.rsplit("/", 1)[0] + "/resolution/" + outputFile.rsplit("/", 1)[1]

  #Generate output file for each resolution allowed
  outputFileOrig = outputFile
  for resolution in iconResolutions:
    #Generate path to outputFile for specific resolution
    outputFile = outputFileOrig.replace("/resolution/", f"/{resolution}px/")

    #Create the directories for the output file if missing
    outputDir = os.path.dirname(outputFile)
    if os.path.exists(outputDir) == False:
      os.makedirs(outputDir, exist_ok=True)

    if iconType == "select":
      resolution = str(getAssetResolutionDir(resolution))
    else:
      resolution = str(resolution)

    #Get process ID for use as a temporary file, if required
    tempFile = outputDir + "/" + str(os.getpid()) + ".png"

    #Generate the icon
    print(f"Processing {inputFile} -> {outputFile} ({tempFile})")
    getCommandExitCode(["inkscape", f"--export-filename={tempFile}", "-h", resolution, inputFile])

    #Compress the icon and move to final destination
    print(f"Compressing {outputFile}...")
    getCommandExitCode(["optipng", "-quiet", "-strip", "all", "-nc", tempFile])
    os.rename(tempFile, outputFile)

if __name__ == "__main__":
  if sys.argv[1] == "--generate":
    #Pass generateIcon() the icon to build and resolutions to build for
    generateIcon(str(sys.argv[4]), str(sys.argv[2]), sys.argv[3].split())
