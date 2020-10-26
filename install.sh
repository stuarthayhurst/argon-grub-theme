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

#Output colours
successCol="\033[1;32m"
messageCol="\033[1;36m"
warningCol="\033[1;33m"
errorCol="\033[1;31m"
boldCol="\033[1;37m"
resetCol="\033[0m"

output() {
  case $1 in
    "success") echo -e "${successCol}${2}${resetCol}";;
    "message") echo -e "${messageCol}${2}${resetCol}";;
    "warning") echo -e "${warningCol}${2}${resetCol}";;
    "error") echo -e "${errorCol}${2}${resetCol}";;
    "normal"|*) echo -e "${boldCol}${2}${resetCol}"
  esac
}

getBackground() {
  background="$1"
  checkArg "$background" || return 1
  if [[ "$1" == "" ]] || [[ "$1" == "list" ]]; then
    output "normal" "Available backgrounds:"
    for availableBackground in "backgrounds/4k/"*; do
      availableBackground="${availableBackground##*/}"
      availableBackground="${availableBackground^}"
      output "success" "  ${availableBackground/.png}"
    done
    output "normal" "Or specify a file (e.g. './install.sh -i -b background.png')"
    exit 0
  fi

  background="${background/.png}"
  if [[ ! -f "$background.png" ]]; then
    if [[ ! -f "backgrounds/4k/${background,,}.png" ]]; then
      output "error" "Invalid background, use './install.sh -b' to view available backgrounds"
      exit 1
    else
      background="${background,,}"
    fi
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
      ""|"list") output "normal" "Valid resolutions: '1080p', '2k', '4k'"; exit 0;;
      *) output "error" "Invalid resolution, using default"; resolution="1080p";;
    esac
  else
    #Use default resolution
    output "warning" "No resolution specified, using 1080p"
    resolution="1080p"
    return 1
  fi
}

getFontSize() {
  fontsize="${1/"px"}"
  if checkArg "$fontsize"; then
    if [[ ! "$fontsize" =~ ^[0-9]+$ ]] || [[ "$fontsize" -gt "32" ]] || [[ "$fontsize" -lt "10" ]]; then
     output "warning" "Font size must be a number between 10 and 32, ignoring"
     fontsize=""
    fi
  else
    #Reset fontsize
    output "warning" "Incorrect usage of --fontsize, ignoring"
    fontsize=""
    return 1
  fi
}

processAssets() {
  assetTypes=("icons" "select" "terminal")
  dpis=("96" "144" "192")

  #Loop through assets and dpis to generate every asset
  for assetType in "${assetTypes[@]}"; do
    srcFile="assets/$assetType.svg"
    assetDir="assets/$assetType"
    for dpi in "${dpis[@]}"; do
      #Generate asset output path
      if [[ "$assetType" != "terminal" ]]; then
        if [[ "$dpi" == "96" ]]; then
          assetDir="assets/$assetType/1080p"
        elif [[ "$dpi" == "144" ]]; then
          assetDir="assets/$assetType/2k"
        elif [[ "$dpi" == "192" ]]; then
          assetDir="assets/$assetType/4k"
        fi
      else
        if [[ "$dpi" == "96" ]]; then
          assetDir="assets/$assetType"
        else
          skip="true"
        fi
      fi
      if [[ "$skip" != "true" ]]; then
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
      fi
      skip="false"
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

installCore() {
  #Generate and install theme.txt
  output "success" "Generating theme.txt..."
  font_size="$fontsize"
  source "theme/theme-values.sh"
  fileContent="$(cat theme/theme-template.txt)"
  fileContent="${fileContent//"{icon_size_template}"/"$icon_size"}"
  fileContent="${fileContent//"{item_icon_space_template}"/"$item_icon_space"}"
  fileContent="${fileContent//"{item_height_template}"/"$item_height"}"
  fileContent="${fileContent//"{item_padding_template}"/"$item_padding"}"
  fileContent="${fileContent//"{item_spacing_template}"/"$item_spacing"}"
  fileContent="${fileContent//"{font_size_template}"/"$font_size"}"
  fileContent="${fileContent//"{font_name_template}"/"$font_name"}"
  echo "$fileContent" > "$installDir/theme.txt"

  #Install theme components
  output "success" "Installing theme assets..."
  cp -r "assets/icons/$resolution" "$installDir/icons"
  cp "assets/select/$resolution/"*.png "$installDir/"
  cp "assets/terminal/"*.png "$installDir/"

  #Generate and install fonts
  generateFont() {
    grub-mkfont "$1" -o "$2" -s "$3"
  }
  generateFont "fonts/DejaVuSans.ttf" "$installDir/dejava_sans_$font_size.pf2" "$font_size"
  generateFont "fonts/Terminus.ttf" "$installDir/terminus_$font_size.pf2" "$font_size"

  #Install background
  if [[ ! -f "$background" ]]; then
    background="backgrounds/$resolution/$background"
  fi
  cp "$background" "$installDir/background.png"
}

installTheme() {
  #Check user is root
  if [[ "$UID" != "0" ]]; then
    output "error" "This script should be run as root"
    exit 1
  fi

  #Remove theme if installed, and recreate directory
  output "success" "Preparing theme directory ($installDir/)..."
  if [[ -d "$installDir" ]]; then
    rm -rf "$installDir"
  fi
  mkdir -p "$installDir"

  #Install files to $installDir
  installCore

  #Install splash screen
  cp "$background" "$splashScreenPath"

  #Modify grub config
  output "success" "Modifiying grub config..."
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

checkCommand() {
  command -v "$1" > /dev/null
}
updateGrub() {
  output "success" "Updating grub..."
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
  #Check user is root
  if [[ "$UID" != "0" ]]; then
    output "error" "This script should be run as root"
    exit 1
  fi

  #Delete assets
  if [[ -d "$installDir" ]]; then
    rm -rf "$installDir"
  else
    output "warning" "Theme wasn't installed, exiting"
    exit 1
  fi

  #Delete splash screen
  if [[ -f "$splashScreenPath" ]]; then
    rm -rf "$splashScreenPath"
  fi

  output "success" "Modifiying grub config..."
  cp -n "/etc/default/grub" "/etc/default/grub.bak"

  #Remove GRUB_THEME from config
  if grep "GRUB_THEME=" /etc/default/grub >/dev/null 2>&1; then
    #Remove GRUB_THEME
    sudo sed -i '/GRUB_THEME=/d' /etc/default/grub
  else
    output "warning" "  GRUB_THEME not found, restoring original backup..."
    #Restore grub config backup
    if [[ -f /etc/default/grub.bak ]]; then
      mv /etc/default/grub.bak /etc/default/grub
    else
      output "error" "No '/etc/default/grub' backup found, exiting"
      output "warning" "You must manually remove the theme from '/etc/default/grub', then update grub"
      exit 1
    fi
  fi

  #Update grub config
  updateGrub
}

previewTheme() {
  if ! checkCommand grub2-theme-preview; then
    echo "No working copy of grub2-theme-preview found"
    echo "grub2-theme-preview: https://github.com/hartwork/grub2-theme-preview"
  fi
  installDir="$(mktemp -d)"

  #Install files to $installDir
  installCore

  echo "Installed to $installDir"
  grub2-theme-preview "$installDir"
  rm -rf "$installDir"
}

if [[ "$#" ==  "0" ]]; then
  output "error" "At least one argument is required, use './install.sh --help' to view options"
  exit 1
fi

validArgList=("-h" "--help" "-i" "--install" "-u" "--uninstall" "-e" "--boot" "-p" "--preview" "-b" "--background" "-r" "--resolution" "-g" "--generate" "-c" "--compress" "--clean")
read -ra args <<< "${@}"; i=0
while [[ $i -le "$(($# - 1))" ]]; do
  arg="${args[$i]}"
  case $arg in
    -h|--help) output "normal"  "Usage: ./install.sh [-OPTION]";
      output "normal"  "Help:"
      output "normal"  "-h | --help       : Display this page"
      output "normal"  "-i | --install    : Install the theme"
      output "normal"  "-u | --uninstall  : Uninstall the theme"
      output "normal"  "-e | --boot       : Install the theme to '/boot/grub/themes'"
      output "normal"  "-p | --preview    : Preview the theme (Works with other options)"
      output "normal"  "-b | --background : Specify which background to use"
      output "normal"  "                  - Leave blank to view available backgrounds"
      output "normal"  "-r | --resolution : Use a specific resolution (Default: 1080p)"
      output "normal"  "                  - Leave blank to view available resolutions"
      output "normal"  "-fs| --fontsize   : Use a specific font size (10-32)"
      output "normal"  "-g | --generate   : Generate icons and other assets"
      output "normal"  "-c | --compress   : Compress icons and other assets"
      output "normal"  "--clean           : Delete all assets except wallpapers"
      output "normal"  "\nRequired arguments: [--install + --background / --uninstall / --generate / --compress / --clean]"; \
      output "success"  "Program written by: Stuart Hayhurst"; exit 0;;
    -i|--install) programOperation="install";;
    -u|--uninstall) programOperation="uninstall";;
    -e|--boot) installDir="/boot/grub/themes/argon";;
    -p|--preview) programOperation="preview";;
    -b|--background) getBackground "${args["$((i + 1))"]}" && i="$((i + 1))";;
    -r|--resolution) getResolution "${args["$((i + 1))"]}" && i="$((i + 1))";;
    -fs|--fontsize|--font-size) getFontSize "${args["$((i + 1))"]}" && i="$((i + 1))";;
    -g|--generate) programOperation="generate";;
    -c|--compress) programOperation="compress";;
    --clean) programOperation="clean";;
    *) output "error"  "Unknown parameter passed: $arg"; exit 1;;
  esac
  i=$((i + 1))
done

warnArgs() {
  if [[ "$resolution" == "" ]]; then
    output "warning"  "No resolution specified, using default of 1080p"
    resolution="1080p"
  fi
  if [[ "$background" == "" ]]; then
    output "error"  "No background specified, use -b to list available backgrounds"
    output "warning"  "  - Call the program with '-b [background]'"
    exit 1
  fi
}

if [[ "$programOperation" == "install" ]]; then
  warnArgs
  installTheme
elif [[ "$programOperation" == "uninstall" ]]; then
  uninstallTheme
elif [[ "$programOperation" == "preview" ]]; then
  warnArgs
  previewTheme
elif [[ "$programOperation" == "generate" ]]; then
  generateAssets
elif [[ "$programOperation" == "compress" ]]; then
  compressAssets
elif [[ "$programOperation" == "clean" ]]; then
  cleanAssets
else
  output "error"  "One of '--install', '--uninstall', '--preview', '--generate', '--compress' or '--clean' is required"
  exit 1
fi
