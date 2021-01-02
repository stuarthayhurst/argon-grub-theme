#!/bin/bash

#Path variables
installDir="/usr/share/grub/themes/argon"
splashScreenPath="/boot/grub/splash0.png"

#Output colours
successCol="\033[1;32m"
listCol="\033[1;36m"
warningCol="\033[1;33m"
errorCol="\033[1;31m"
boldCol="\033[1;37m"
resetCol="\033[0m"

checkArg() {
  for validArg in "${validArgList[@]}"; do
    if [[ "$1" == "$validArg" ]]; then
      return 1
    fi
  done
}

checkCommand() {
  command -v "$1" > /dev/null
}

checkRoot() {
  if [[ "$UID" != "0" ]]; then
    return 1
  fi
}

output() {
  case $1 in
    "success") echo -e "${successCol}${2}${resetCol}";;
    "list") echo -e "${listCol}${2}${resetCol}";;
    "warning") echo -e "${warningCol}${2}${resetCol}";;
    "error") echo -e "${errorCol}${2}${resetCol}";;
    "normal"|*) echo -e "${boldCol}${2}${resetCol}";;
  esac
}

getBackground() {
  background="$1"
  checkArg "$background" || return 1
  if [[ "$1" == "" ]] || [[ "$1" == "list" ]]; then
    output "list" "Available backgrounds:"
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
      "custom") resolution="custom";;
      ""|"list") output "normal" "Valid resolutions: '1080p', '2k', '4k', 'custom'"; exit 0;;
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
    if [[ ! "$fontsize" =~ ^[0-9]+$ ]]; then
     output "warning" "Font size must be an integer, ignoring"
     fontsize=""
    fi
  else
    #Reset fontsize
    output "warning" "Incorrect usage of --fontsize, ignoring"
    fontsize=""
    return 1
  fi
}

getFontFile() {
  fontfile="$1"
  checkArg "$fontfile" || return 1
  if [[ "$1" == "" ]] || [[ "$1" == "list" ]]; then
    output "list" "Available fonts:"
    for availableFont in "fonts/"*".ttf"; do
      availableFont="${availableFont##*/}"
      output "success" "  $availableFont"
    done
    output "normal" "Or specify a file (e.g. './install.sh -i -f Font.ttf')"
    exit 0
  fi

  if [[ ! -f "$fontfile" ]]; then
    if [[ -f "fonts/${fontfile}" ]]; then
      fontfile="$fontfile"
    elif [[ -f "fonts/${fontfile}.ttf" ]]; then
      fontfile="$fontfile".ttf
    elif [[ -f "fonts/${fontfile}.ttf" ]]; then
      fontfile="$fontfile".otf
    else
      output "error" "Invalid fontfile, use './install.sh -f' to view available fonts"
      exit 1
    fi
  fi
  fontfile="$fontfile"
}


generateIcons() {
  #generateIcons "resolution" "icons/select" "default/install" "svgFile"
  generateIcon() {
    pngFile="${svgFile##*/}"
    pngFile="${pngFile/.svg/.png}"
    if checkCommand inkscape; then
      inkscape "-h" "$assetSize" "--export-filename=$buildDir/$pngFile" "$svgFile" >/dev/null 2>&1
    elif checkCommand convert; then
      output "warning" "Low quality: Inkscape not found, using imagemagick..."
      convert -scale "x$assetSize" -extent "x$assetSize" -background none "$svgFile" "$buildDir/$pngFile"
    else
      output "error" "Neither inkscape or convert are available"
      output "warning" "Please install inkscape or imagemagick (preferably inkscape)"
    fi
  }
  assetSize="${1/px}"
  if [[ "$3" == "default" ]] && [[ "$2" == "select" ]]; then
    case $assetSize in
      "37") assetSizeDir="32";;
      "56") assetSizeDir="48";;
      "74") assetSizeDir="64";;
    esac
  else
    assetSizeDir="$assetSize"
  fi
  if [[ "$3" == "default" ]]; then
    buildDir="./assets/$2/${assetSizeDir}px"
  elif [[ "$3" == "install" ]]; then
    buildDir="./build/$2"
  fi
  mkdir -p "$buildDir"
  if [[ "$3" == "default" ]]; then
    svgFile="./$4"
    generateIcon
  else
    for svgFile in "./assets/svg/$2/"*; do
      generateIcon
    done
  fi
}

generateThemeSizes() {
  icon_size="$(($1 * 2))"
  item_icon_space="$((icon_size / 2 + 2))"
  item_height="$((icon_size / 6 + icon_size))"
  item_padding="$((icon_size / 4))"
  item_spacing="$((icon_size / 3))"
}

installCore() {
  #Generate theme size values
  generateThemeSizes "$fontsize"

  #Generate and set path for icons
  if [[ ! -d "./assets/icons/${icon_size}px" ]]; then
    output "success" "Generating theme assets..."
    generateIcons "$icon_size" "icons" "install"
    generateIcons "$item_height" "select" "install"
    iconDir="./build/icons"
    selectDir="./build/select"
  else
    iconDir="./assets/icons/${icon_size}px"
    selectDir="./assets/select/${icon_size}px"
  fi

  #Install theme components
  output "success" "Installing theme assets..."
  cp -r "$iconDir" "$installDir/icons"
  cp "$selectDir/"*.png "$installDir/"

  #Generate and install fonts
  generateFont() {
    #"input" "output" "size" "font family"
    if checkCommand grub-mkfont; then
      if [[ "$forceBoldFont" == "true" ]] || [[ "$5" == "-b" ]]; then
        grub-mkfont "$1" -o "$2" -s "$3" -n "$4" "-b"
      else
        grub-mkfont "$1" -o "$2" -s "$3" -n "$4"
      fi
    else
      output "error" "grub-mkfont couldn't be found, exiting"
      exit 1
    fi
  }
  output "success" "Generating fonts..."
  generateFont "fonts/$fontfile" "$installDir/${fontfile%.*}_$fontsize.pf2" "$fontsize" "Display"
  generateFont "fonts/Terminus.ttf" "$installDir/Terminus_16.pf2" "16" "Console" "-b"
  font_name="$(file "$installDir/${fontfile%.*}_$fontsize.pf2")"
  font_name="${font_name#*": GRUB2 font "}"
  font_name="${font_name//'"'}"
  console_font_name="Console Bold 16"

  #Fill out and install theme.txt
  output "success" "Creating theme.txt..."
  fileContent="$(cat assets/theme.txt)"
  fileContent="${fileContent//"{icon_size_template}"/"$icon_size"}"
  fileContent="${fileContent//"{item_icon_space_template}"/"$item_icon_space"}"
  fileContent="${fileContent//"{item_height_template}"/"$item_height"}"
  fileContent="${fileContent//"{item_padding_template}"/"$item_padding"}"
  fileContent="${fileContent//"{item_spacing_template}"/"$item_spacing"}"
  fileContent="${fileContent//"{font_name_template}"/"$font_name"}"
  fileContent="${fileContent//"{console_font_name_template}"/"$console_font_name"}"
  #Append the help label if enabled
  if [[ "$helpLabel" == "true" ]]; then
    fileContent+="$(echo -e "\n"; cat "assets/help-label.txt")"
  fi
  echo "$fileContent" > "$installDir/theme.txt"

  #Install background
  if [[ ! -f "$background" ]]; then
    background="backgrounds/$resolution/$background"
  fi
  cp "$background" "$installDir/background.png"
}

installTheme() {
  #Check user is root
  if ! checkRoot; then
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
  else
    gfxmode="GRUB_GFXMODE=auto"
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
  output "success" "Updating grub..."
  if checkCommand update-grub; then
    update-grub
  elif checkCommand grub-mkconfig; then
    grub-mkconfig -o /boot/grub/grub.cfg
  elif checkCommand zypper; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
  elif checkCommand dnf; then
    grub2-mkconfig -o /boot/grub2/grub.cfg || grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
  fi
}

uninstallTheme() {
  #Check user is root
  if ! checkRoot; then
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
    output "error" "No working copy of grub2-theme-preview found"
    output "warning" "grub2-theme-preview: https://github.com/hartwork/grub2-theme-preview"
    if checkRoot; then
      output "warning" "If grub2-theme-preview was installed without the -g switch, it won't be available"
      output "warning" "Running './install.sh' again without root may work"
    fi
    exit 1
  fi
  installDir="$(mktemp -d)"

  #Install files to $installDir
  installCore

  output "success" "Installed to $installDir"
  grub2-theme-preview "$installDir"
  rm -rf "$installDir"
}

if [[ "$#" ==  "0" ]]; then
  output "error" "At least one argument is required, use './install.sh --help' to view options"
  exit 1
fi

validArgList=("-h" "--help" "-i" "--install" "-u" "--uninstall" "-e" "--boot" "-p" "--preview" "-b" "--background" "-r" "--resolution" "-fs" "--fontsize" "--font-size" "-f" "--font" "-l" "--bold")
read -ra args <<< "${@}"; i=0
while [[ $i -le "$(($# - 1))" ]]; do
  arg="${args[$i]}"
  case $arg in
    -h|--help) output "normal" "Usage: ./install.sh [-OPTION]";
      output "normal" "Help:"
      output "normal" "-h | --help       : Display this page"
      output "normal" "-i | --install    : Install the theme"
      output "normal" "-u | --uninstall  : Uninstall the theme"
      output "normal" "-e | --boot       : Install the theme to '/boot/grub/themes'"
      output "normal" "-p | --preview    : Preview the theme (Works with other options)"
      output "normal" "-b | --background : Specify which background to use"
      output "normal" "                  - Leave blank to view available backgrounds"
      output "normal" "-r | --resolution : Use a specific resolution (Default: 1080p)"
      output "normal" "                  - Leave blank to view available resolutions"
      output "normal" "-fs| --fontsize   : Use a specific font size"
      output "normal" "-f | --font       : Use a specific font"
      output "normal" "-l | --bold       : Force font to be bold"
      output "normal" "-hl| --help-label : Add a help label to the bottom of the theme"
      output "normal" "\nRequired arguments: [--install + --background / --uninstall / --preview]"
      output "success" "Program written by: Stuart Hayhurst"; exit 0;;
    -i|--install) programOperation="install";;
    -u|--uninstall) programOperation="uninstall";;
    -e|--boot) installDir="/boot/grub/themes/argon";;
    -p|--preview) programOperation="preview";;
    -b|--background) getBackground "${args["$((i + 1))"]}" && i="$((i + 1))";;
    -r|--resolution) getResolution "${args["$((i + 1))"]}" && i="$((i + 1))";;
    -fs|--fontsize|--font-size) getFontSize "${args["$((i + 1))"]}" && i="$((i + 1))";;
    -f|--font) getFontFile "${args["$((i + 1))"]}" && i="$((i + 1))";;
    -l|--bold) forceBoldFont="true";;
    -hl|--help-label) helpLabel="true";;
    -g|--generate) generateIcons "${args["$((i + 1))"]}" "${args["$((i + 2))"]}" "${args["$((i + 3))"]}" "${args["$((i + 4))"]}"; exit;;
    *) output "error" "Unknown parameter passed: $arg"; exit 1;;
  esac
  i=$((i + 1))
done

warnArgs() {
  if [[ "$resolution" == "" ]]; then
    output "warning" "No resolution specified, using default of 1080p"
    resolution="1080p"
  fi
  if [[ "$fontsize" == "" ]]; then
    output "warning" "No fontsize specified, use -fs [VALUE] to set a font size"
    output "warning" "  - Default of 24 will be used"
    fontsize="24"
  fi
  if [[ "$fontfile" == "" ]]; then
    output "warning" "No font specified, use -f [FONTFILE] to set a font, using Terminus Bold"
    forceBoldFont="true"
    fontfile="Terminus.ttf"
  fi
  if [[ "$background" == "" ]]; then
    output "error" "No background specified, use -b to list available backgrounds"
    output "warning" "  - Call the program with '-b [background]'"
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
else
  output "error" "One of '--install', '--uninstall' or '--preview' is required"
  exit 1
fi
