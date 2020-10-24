#!/bin/bash

installDir="/usr/share/grub/themes/argon"
splashScreenPath="/boot/grub/splash0.png"

checkArg() {
  for validArg in "${validArgList[@]}"; do
    if [[ "$1" == "$validArg" ]]; then
      return 1
    fi
  done
}

getBackground() {
  background="$1"
  checkArg "$background" || return 1
  if [[ "$1" == "" ]] || [[ "$1" == "list" ]]; then
    echo "Available backgrounds:"
    for availableBackground in "backgrounds/4k/"*; do
      echo "  ${availableBackground##*/}"
    done
    echo "Or specify a file (e.g. './install.sh -i -b background.png')"
    exit 0
  fi

  background="${background/.png}"
  if [[ ! -f "backgrounds/4k/$background.png" ]] && [[ ! -f "$background.png" ]]; then
    echo "Invalid background, use './install.sh -b' to view available backgrounds"
    exit 1
  fi
  background="$background.png"
}

getResolution() {
  resolution="$1"
  if checkArg "$resolution"; then
    #Check if it's a valid resolution, otherwise use default
    case "$resolution" in
      4k|4K|3480x2160|2160p) resolution="4k";;
      2k|2K|2560x1440|1440p) resolution="2k";;
      1920x1080|1080p) resolution="1080p";;
      ""|"list") echo "Valid resolutions: '1080p', '2k', '4k'"; exit 0;;
      *) echo "Invalid resolution, using default"; resolution="1080p";;
    esac
  else
    #Use default resolution
    echo "No resolution specified, using 1080p"
    resolution="1080p"
    return 1
  fi
}

processAssets() {
  assetTypes=("icons" "select")
  dpis=("96" "144" "192")

  #Loop through assets and dpis to generate every asset
  for assetType in "${assetTypes[@]}"; do
    srcFile="assets/$assetType.svg"
    assetDir="assets/$assetType"
    for dpi in "${dpis[@]}"; do
      #Generate asset output path
      if [[ "$dpi" == "96" ]]; then
        assetDir="assets/$assetType/1080p"
      elif [[ "$dpi" == "144" ]]; then
        assetDir="assets/$assetType/2k"
      elif [[ "$dpi" == "192" ]]; then
        assetDir="assets/$assetType/4k"
      fi
      mkdir -p "$assetDir"
      echo -e "\nUsing options \"$assetType\" \"$dpi\": \n"
      while read -r line; do
        #Split $line into the icon's id and icon name
        iconId="${line%%,*}"
        icon="${line##*,}"

        if [[ "$line" != "" ]]; then
          echo -n "${1^} $assetDir/$icon.png..."
          if [[ "$1" == "generating" ]]; then
            if [[ ! -f "$assetDir/$icon.png" ]]; then #Check if the icon already exists
              inkscape  "--export-id=$iconId" \
                        "--export-dpi=$dpi" \
                        "--export-id-only" \
                        "--export-filename=$assetDir/$icon.png" "$srcFile" >/dev/null 2>&1
              echo " Done"
            else
              echo -e "\n  File '$assetDir/$icon.png' already exists"
            fi
          elif [[ "$1" == "compressing" ]]; then #Compress asset
            if [[ -f "$assetDir/$icon.png" ]]; then #Check file exists first
              optipng -o7 --quiet "$assetDir/$icon.png"
            fi
            echo " Done"
          fi
        fi
     done < "assets/$assetType.csv"
    done
  done
}

generateAssets() {
  processAssets "generating"
}

compressAssets() {
  processAssets "compressing"
  #Compress backgrounds
  echo ""
  for resolution in "backgrounds/"*; do
    for background in "$resolution/"*; do
      echo -n "Compressing $background..."
      optipng --quiet "$background"
      echo " Done"
    done
  done
}

cleanAssets() {
  rm -rvf "./assets/icons/"*
  rm -rvf "./assets/select/"*
}

installTheme() {
  #Check user is root
  if [[ "$UID" != "0" ]]; then
    echo "This script should be run as root"
    exit 1
  fi

  #Remove theme if installed, and recreate directory
  echo "Preparing theme directory ($installDir/)..."
  if [[ -d "$installDir" ]]; then
    rm -rf "$installDir"
  fi
  mkdir -p "$installDir"

  #Install theme components
  echo "Installing theme assets..."
  cp "common/"{*.png,*.pf2} "$installDir/"
  cp "config/theme-$resolution.txt" "$installDir/theme.txt"
  cp -r "assets/icons/$resolution" "$installDir/icons"
  cp "assets/select/$resolution/"*.png "$installDir/"

  #Install background and splash screen
  if [[ ! -f "$background" ]]; then
    background="backgrounds/$resolution/$background"
  fi
  cp "$background" "$installDir/background.png"
  cp "$background" "$splashScreenPath"

  #Modify grub config
  echo "Modifiying grub config..."
  cp -n "/etc/default/grub" "/etc/default/grub.bak"

  if grep "GRUB_THEME=" /etc/default/grub >/dev/null 2>&1; then
    #Replace GRUB_THEME
    sed -i "s|.*GRUB_THEME=.*|GRUB_THEME=\"$installDir/theme.txt\"|" /etc/default/grub
  else
    #Append GRUB_THEME
    echo "GRUB_THEME=\"$installDir/theme.txt\"" >> /etc/default/grub
  fi

  #Set the correct resolution for grub
  if [[ "$resolution" == '1080p' ]]; then
    gfxmode="GRUB_GFXMODE=1920x1080,auto"
  elif [[ "$resolution" == '4k' ]]; then
    gfxmode="GRUB_GFXMODE=3840x2160,auto"
  elif [[ "$resolution" == '2k' ]]; then
    gfxmode="GRUB_GFXMODE=2560x1440,auto"
  fi

  if grep "GRUB_GFXMODE=" /etc/default/grub >/dev/null 2>&1; then
    #Replace GRUB_GFXMODE
    sed -i "s|.*GRUB_GFXMODE=.*|${gfxmode}|" /etc/default/grub
  else
    #Append GRUB_GFXMODE
    echo "${gfxmode}" >> /etc/default/grub
  fi

  if grep "GRUB_TERMINAL=console" /etc/default/grub >/dev/null 2>&1 || grep "GRUB_TERMINAL=\"console\"" /etc/default/grub >/dev/null 2>&1; then
    #Replace GRUB_TERMINAL
    sed -i "s|.*GRUB_TERMINAL=.*|#GRUB_TERMINAL=console|" /etc/default/grub
  fi

  if grep "GRUB_TERMINAL_OUTPUT=console" /etc/default/grub >/dev/null 2>&1 || grep "GRUB_TERMINAL_OUTPUT=\"console\"" /etc/default/grub >/dev/null 2>&1; then
      #Replace GRUB_TERMINAL_OUTPUT
    sed -i "s|.*GRUB_TERMINAL_OUTPUT=.*|#GRUB_TERMINAL_OUTPUT=console|" /etc/default/grub
  fi

  #Update grub config
  updateGrub
}

updateGrub() {
  checkCommand() {
    command -v "$1" > /dev/null
  }
  echo "Updating grub..."
  if checkCommand update-grub; then
    update-grub
  elif checkCommand grub-mkconfig; then
    grub-mkconfig -o /boot/grub/grub.cfg
  elif checkCommand zypper; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
  elif checkCommand dnf; then
    grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
  fi
}

uninstallTheme() {
  #Delete assets
  if [[ -d "$installDir" ]]; then
    rm -rf "$installDir"
  else
    echo "Theme wasn't installed, exiting"
    exit 1
  fi

  #Delete splash screen
  if [[ -f "$splashScreenPath" ]]; then
    rm -rf "$splashScreenPath"
  fi

  echo "Modifiying grub config..."
  cp -n "/etc/default/grub" "/etc/default/grub.bak"

  #Remove GRUB_THEME from config
  if grep "GRUB_THEME=" /etc/default/grub >/dev/null 2>&1; then
    #Remove GRUB_THEME
    sudo sed -i "s|.*GRUB_THEME=.*||" /etc/default/grub
  else
    echo "GRUB_THEME not found, restoring original backup..."
    #Restore grub config backup
    if [[ -f /etc/default/grub.bak ]]; then
      mv /etc/default/grub.bak /etc/default/grub
    else
      echo "No '/etc/default/grub' backup found, exiting"
      echo "You must manually remove the theme from '/etc/default/grub', then update grub"
      exit 1
    fi
  fi

  #Update grub config
  updateGrub
}

if [[ "$#" ==  "0" ]]; then
  echo "At least one argument is required, use './install.sh --help' to view options"
  exit 1
fi

validArgList=("-h" "--help" "-i" "--install" "-u" "--uninstall" "-e" "--boot" "-b" "--background" "-r" "--resolution" "-g" "--generate" "-c" "--compress" "--clean")
read -ra args <<< "${@}"; i=0
while [[ $i -le "$(($# - 1))" ]]; do
  arg="${args[$i]}"
  case $arg in
    -h|--help) echo "Usage: ./install.sh [-OPTION]";
      echo "Help:"
      echo "-h | --help       : Display this page"
      echo "-i | --install    : Install the theme"
      echo "-u | --uninstall  : Uninstall the theme"
      echo "-e | --boot       : Install the theme to '/boot/grub/themes'"
      echo "-b | --background : Specify which background to use"
      echo "                  - Leave blank to view available backgrounds"
      echo "-r | --resolution : Use a specific resolution (Default: 1080p)"
      echo "                  - Leave blank to view available resolutions"
      echo "-g | --generate   : Generate icons and other assets"
      echo "-c | --compress   : Compress icons and other assets"
      echo "--clean           : Delete all assets except wallpapers"
      echo -e "\nRequired arguments: [--install + --background / --uninstall / --generate / --compress / --clean]"; \
      echo "Program written by: Stuart Hayhurst"; exit 0;;
    -i|--install) programOperation="install";;
    -u|--uninstall) programOperation="uninstall";;
    -e|--boot) installDir="/boot/grub/themes/argon";;
    -b|--background) getBackground "${args["$((i + 1))"]}" && i="$((i + 1))";;
    -r|--resolution) getResolution "${args["$((i + 1))"]}" && i="$((i + 1))";;
    -g|--generate) programOperation="generate";;
    -c|--compress) programOperation="compress";;
    --clean) programOperation="clean";;
    *) echo "Unknown parameter passed: $arg"; exit 1;;
  esac
  i=$((i + 1))
done

if [[ "$programOperation" == "install" ]]; then
  if [[ "$resolution" == "" ]]; then
    echo "No resolution specified, using default of 1080p"
    resolution="1080p"
  fi
  if [[ "$background" == "" ]]; then
    echo "No background specified, use -b to list available backgrounds"
    echo "  - Call the program with '-b [background]'"
    exit 1
  fi
  installTheme
elif [[ "$programOperation" == "uninstall" ]]; then
  uninstallTheme
elif [[ "$programOperation" == "generate" ]]; then
  generateAssets
elif [[ "$programOperation" == "compress" ]]; then
  compressAssets
elif [[ "$programOperation" == "clean" ]]; then
  cleanAssets
else
  echo "One of '--install', '--uninstall', '--generate', '--compress' or '--clean' is required"
  exit 1
fi
