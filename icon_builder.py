#!/usr/bin/python3
import sys, subprocess, os, glob

def isSymlinkBroken(path):
  if os.path.islink(path):
    #Generate path to symlink target
    linkPath = str(os.path.dirname(path)) + "/" + str(os.readlink(path))
    if os.path.isfile(linkPath) == False:
      #Symlink is broken
      return True
  #Either not a symlink, or not broken
  return False

def getCommandExitCode(command):
  return subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode

def getCommandOutput(command):
  output = subprocess.run(command, capture_output=True).stdout.decode("utf-8").split("\n")
  if "" in output:
    output.remove("")
  return output

def getAssetResolutionDir(resolution):
  convertDict = {
    "32": "37",
    "48": "56",
    "64": "74"
  }

  if resolution in convertDict:
    return convertDict[str(resolution)]
  else:
    return str(resolution)

#Generates the given icon for all required resolutions
def generateIconResolutions(inputFile, iconType, iconResolutions):
  #Generate output file path by swapping to a png
  outputFile = inputFile.replace(".svg", ".png")
  outputFile = outputFile.replace("svg/", "")
  outputFile = outputFile.rsplit("/", 1)[0] + "/resolution/" + outputFile.rsplit("/", 1)[1]

  #for iconResolution in iconResolutions:
  generateIcon(inputFile, outputFile, iconType, iconResolutions)

#Generates all icons for a specific resolution
def generateIconSet(buildDir, iconType, iconColour, iconResolution):
  if iconColour == "coloured":
    iconColour = "icons"
  else:
    iconColour = "icons-colourless"

  iconDir = f"assets/svg/{iconType}"
  iconDir = iconDir.replace("icons", iconColour)

  for icon in glob.glob(f"{iconDir}/*.svg"):
    #Work out output file and generate icon
    outputFile = f"{buildDir}/" + icon.split("/", 2)[2]
    outputFile = outputFile.rsplit("/", 1)[0] + f"/{iconResolution}px/" + outputFile.rsplit("/", 1)[1]
    outputFile = outputFile.replace(".svg", ".png")
    generateIcon(icon, outputFile, iconType, [iconResolution])

#Generates the given icon for all required resolutions
def generateIcon(inputFile, outputFile, iconType, iconResolutions):
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
      resolution = getAssetResolutionDir(resolution)
    else:
      resolution = str(resolution)

    #Get process ID for use as a temporary file, if required
    tempFile = outputDir + "/" + str(os.getpid()) + ".png"

    #Generate the icon
    print(f"Processing {inputFile} -> {outputFile} ({tempFile})")
    getCommandExitCode(["inkscape", f"{inkscapeExport}={tempFile}", "-h", resolution, inputFile])

    #Compress the icon and move to final destination
    print(f"Compressing {outputFile}...")
    getCommandExitCode(["optipng", "-quiet", "-strip", "all", "-nc", tempFile])
    os.rename(tempFile, outputFile)

def checkFiles(buildDir):
  if os.path.exists(buildDir) == False:
    print(f"Build directory '{buildDir}' doesn't exist, exiting")
    exit(1)

  for file in glob.glob(f"{buildDir}/svg/*/*.svg"):
    if isSymlinkBroken(file):
      print(f"{file} is a broken symlink, exiting")
      exit(1)
    if "/icons/" in file:
      if os.path.exists(file.replace("/icons/", "/icons-colourless/")) == False:
        print(f"{file} is missing a colourless counterpart, exiting")
        exit(1)

#Figure out inkscape generation option
inkscapeVersion = getCommandOutput(["inkscape", "--version"])[0].split(" ")[1]
inkscapeVersion = inkscapeVersion.split(".")
inkscapeVersion = float(f"{inkscapeVersion[0]}.{inkscapeVersion[1]}")

if inkscapeVersion >= 1.0:
  inkscapeExport = "--export-filename"
else:
  inkscapeExport = "--export-png"

if __name__ == "__main__":
  if sys.argv[1] == "--generate":
    #Pass generateIcon() icon to build, icon type and resolutions to build for
    #Generates all resolutions for that specific icon
    generateIconResolutions(str(sys.argv[4]), str(sys.argv[2]), sys.argv[3].split())
  elif sys.argv[1] == "--custom":
    #Pass generateIconSet() the build dir, icon type and resolution to build for
    #Generates all icons for that specific resolution
    generateIconSet(str(sys.argv[4]), str(sys.argv[2]), str(sys.argv[5]), str(sys.argv[3]))
  elif sys.argv[1] == "--check-files":
    #Pass checkFiles() the build directory
    checkFiles(str(sys.argv[2]))
