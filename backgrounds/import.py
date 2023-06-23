#!/usr/bin/python3

import os, shutil, glob
import subprocess
import multiprocessing

upstreamRepo = "https://github.com/stuarthayhurst/argon-wallpapers.git"
upstreamBranch = "master"

knownResolutions = {
  "4k": {"width": 3840, "height": 2160},
  "2k": {"width": 2560, "height": 1440},
  "1080p": {"width": 1920, "height": 1080}
}

knownWallpapers = {
  "ColourWaves.png": "colours.png",
  "Crystals.png": "crystals.png",
  "DarkWaves.png": "darkwaves.png",
  "Dawn.png": "dawn.png",
  "Dusk.png": "dusk.png",
  "Grey.png": "grey.png",
  "Waves.png": "waves.png",
}

#Create a list of outputs with name, format and resolution
outputEntries = []
for directory in os.scandir():
  #Filter out files and symlinks
  if not directory.is_dir(follow_symlinks = False):
    continue

  #Filter out previous runs
  if directory.name == "upstream":
    continue

  #Decide output mode
  backgroundFormat = "regular"
  if "x" in directory.name:
    backgroundFormat = "tall"

  #Extract width and height
  width, height = 0, 0
  if str(directory.name) in knownResolutions:
    width = knownResolutions[directory.name]["width"]
    height = knownResolutions[directory.name]["height"]
  elif "x" in directory.name:
    width = directory.name.split("x")[0]
    height = directory.name.split("x")[1]
  else:
    print(f"Failed to process {directory.name}, couldn't guess resolution")

  #Save output entry
  outputEntry = {
    "name": directory.name,
    "format": backgroundFormat,
    "width": width,
    "height": height
  }
  outputEntries.append(outputEntry)

#Shallow clone the upstream wallpapers
command = ["git", "clone", "--depth", "1", "-b", upstreamBranch, upstreamRepo, "upstream"]
subprocess.run(command)
os.chdir("./upstream")

freshEnv = os.environ.copy()

threads = multiprocessing.cpu_count()
input(f"\nGoing to import {len(outputEntries)} resolutions using {threads} threads, continue?")

#Export wallpapers with each set of settings
for outputEntry in outputEntries:
  target = "wallpapers"
  if outputEntry["format"] == "tall":
    target = "tall"

  #Set width and height for the output
  freshEnv["EXPORT_WIDTH"] = str(outputEntry['width'])
  freshEnv["EXPORT_HEIGHT"] = str(outputEntry['height'])

  #Generate the wallpapers
  command = ["make", target, f"-j{threads}"]
  exitCode = subprocess.run(command, env = freshEnv).returncode
  if exitCode != 0:
    print(f"Failed to generate {outputEntry['width']}x{outputEntry['height']} backgrounds")
    exit(1)

  #Tall wallpapers are generated to a different path
  extraPath = ""
  if outputEntry["format"] == "tall":
    extraPath = "tall/"

  #Move and rename generated wallpapers
  pngFiles = glob.glob(f"./{extraPath}*.png")
  for pngFile in pngFiles:
    fileName = os.path.basename(pngFile)
    if fileName in knownWallpapers:
      wallpaperName = knownWallpapers[fileName]
      shutil.move(pngFile, f"../{outputEntry['name']}/{wallpaperName}")
    else:
      print(f"Unrecognised wallpaper '{fileName}', ignoring")

#Done, remove cloned repository
print("\nImport complete")
print(f"Use 'cd ../; make compress-backgrounds -j{threads}' to apply compression")
os.chdir("../")
shutil.rmtree("upstream")
