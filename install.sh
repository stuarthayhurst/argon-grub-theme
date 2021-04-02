#!/bin/bash

#Path variables
installDir="/usr/share/grub/themes/argon"

#Set bootPath for future reference, and to set splashScreenPath
if [[ -d "/boot/grub" ]]; then
  bootPath="/boot/grub"
elif [[ -d "/boot/grub2" ]]; then
  bootPath="/boot/grub2"
fi
splashScreenPath="$bootPath/splash0.png"

#Output colours
successCol="\033[1;32m"
listCol="\033[1;36m"
warningCol="\033[1;33m"
errorCol="\033[1;31m"
boldCol="\033[1;37m"
resetCol="\033[0m"

#Checks whether argument is a program argument or data
checkArg() {
  for validArg in "${validArgList[@]}"; do
    if [[ "$1" == "$validArg" ]]; then
      return 1
    fi
  done
}

#Check whether a command exists, silently
checkCommand() {
  command -v "$1" > /dev/null
}

#Checks whether the current user is root or not
checkRoot() {
  if [[ "$UID" != "0" ]]; then
    return 1
  fi
}

#Output messages with colours based off of categories
#$3 - whether or not to output a newline, $2 - actual message
output() {
  extraContent="\n"
  if [[ "$3" == "noNewline" ]]; then
    extraContent=""
  fi
  case $1 in
    "success") echo -en "${successCol}${2}${resetCol}${extraContent}";;
    "list"|"minor") echo -en "${listCol}${2}${resetCol}${extraContent}";;
    "warning") echo -en "${warningCol}${2}${resetCol}${extraContent}";;
    "error") echo -en "${errorCol}${2}${resetCol}${extraContent}";;
    "normal"|*) echo -en "${boldCol}${2}${resetCol}${extraContent}";;
  esac
}

#Processes the background argument (listing and validating)
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

#Processes the custom background argument (validating)
getCustomBackground() {
  backgroundColour="${1}"
  #Check $background_colour is valid (not another argument)
  if ! checkArg "$backgroundColour" || [[ "$backgroundColour" == "" ]]; then
    #Give error message if it failed
    output "warning" "Invalid or no background colour found, ignoring"
    backgroundColour=""
    return 1
  fi
}

#Processes the resolutiom argument (listing, validating)
getResolution() {
  resolution="$1"
  if checkArg "$resolution"; then
    #Check if it's a valid resolution, otherwise use default
    case "$resolution" in
      4k|4K|3480x2160|2160p) resolution="4k"; gfxmode="GRUB_GFXMODE=3840x2160,auto";;
      2k|2K|2560x1440|1440p) resolution="2k"; gfxmode="GRUB_GFXMODE=2560x1440,auto";;
      1920x1080|1080p) resolution="1080p"; gfxmode="GRUB_GFXMODE=1920x1080,auto";;
      *x*) resolution="$resolution"; gfxmode="GRUB_GFXMODE=$resolution,auto"; echo "Custom resolution found, using \"$resolution\"";;
      "custom") resolution="custom"; gfxmode="GRUB_GFXMODE=auto";;
      ""|"list") output "normal" "Valid resolutions: '1080p', '2k', '4k', 'custom' or '[WIDTH]x[HEIGHT]'"; exit 0;;
      *) output "error" "Invalid resolution, using default"; resolution="1080p";;
    esac
  else
    #Use default resolution
    output "warning" "No resolution specified, using 1080p"
    resolution="1080p"
    gfxmode="GRUB_GFXMODE=1920x1080,auto"
    return 1
  fi
}

#Processes the font colour argument (validating)
getFontColour() {
  font_colour="${1%,*}"
  selected_font_colour="${1#*,}"
  #Check $font_colour is valid (not another argument)
  if ! checkArg "$font_colour" || ! checkArg "$selected_font_colour" || [[ "$font_colour" == "" ]] || [[ "$selected_font_colour" == "" ]]; then
    #Give error message if it failed
    output "warning" "Invalid or no font colour found, ignoring"
    font_colour=""
    return 1
  fi
}

#Processes the font size argument (validating)
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

#Processes the font argument (listing, validating)
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
    elif [[ -f "fonts/${fontfile}.otf" ]]; then
      fontfile="$fontfile".otf
    else
      output "error" "Invalid fontfile, use './install.sh -f' to view available fonts"
      exit 1
    fi
  fi
  fontfile="$fontfile"
}

#Generates assets for the theme is a custom resolution is required
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
    buildDir="./build/$2/${assetSizeDir}px"
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

installCore() {
  generateFont() {
    #"input" "output" "size" "font family"
    if checkCommand grub-mkfont; then
      mkfontCommand="grub-mkfont"
    elif checkCommand grub2-mkfont; then
      mkfontCommand="grub2-mkfont"
    else
      output "error" "Neither grub-mkfont grub2-mkfont could be found, exiting"
      exit 1
    fi

    if [[ "$forceBoldFont" == "true" ]] || [[ "$5" == "-b" ]]; then
      forceBoldFont="-b"
    fi
    $mkfontCommand "$1" -o "$2" -s "$3" -n "$4" "$forceBoldFont"
  }

  generateThemeSizes() {
    icon_size="$(($1 * 2))"
    item_icon_space="$((icon_size / 2 + 2))"
    item_height="$((icon_size / 6 + icon_size))"
    item_padding="$((icon_size / 4))"
    item_spacing="$((icon_size / 3))"
  }

  #Generate theme size values
  generateThemeSizes "$fontsize"

  #Generate assets and set path
  if [[ -d "./assets/icons/${icon_size}px" ]]; then #Decide whether assets need to be generated
    iconDir="./assets/icons/${icon_size}px"
    selectDir="./assets/select/${icon_size}px"
  else
    checkIconCached() { #$1: asset name, $2: resolution, $3: pretty name
      #Decide if the assets have been cached
      output "success" "Generating $3..." "noNewline"
      if [[ ! -d "./build/$1/${2}px" ]]; then
        generateIcons "$2" "$1" "install"
        output "success" " done"
      else
        output "success" " found cached $3"
      fi
    }

    #Check if icons are cached and regenerate if not
    checkIconCached "icons" "$icon_size" "icons"
    checkIconCached "select" "$item_height" "assets"

    iconDir="./build/icons/${icon_size}px"
    selectDir="./build/select/${item_height}px"
  fi

  #Install theme components
  output "success" "Installing theme assets..."
  cp -r "$iconDir" "$installDir/icons"
  cp "$selectDir/"*.png "$installDir/"

  #Generate and install fonts
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
  #Append the help label if enabled
  if [[ "$helpLabel" == "true" ]]; then
    fileContent+="$(echo -e "\n"; cat "assets/help-label.txt")"
  fi
  fileContent="${fileContent//"{icon_size_template}"/"$icon_size"}"
  fileContent="${fileContent//"{item_icon_space_template}"/"$item_icon_space"}"
  fileContent="${fileContent//"{item_height_template}"/"$item_height"}"
  fileContent="${fileContent//"{item_padding_template}"/"$item_padding"}"
  fileContent="${fileContent//"{item_spacing_template}"/"$item_spacing"}"
  fileContent="${fileContent//"{font_name_template}"/"$font_name"}"
  fileContent="${fileContent//"{console_font_name_template}"/"$console_font_name"}"
  fileContent="${fileContent//"{font_colour_template}"/"$font_colour"}"
  fileContent="${fileContent//"{selected_font_colour_template}"/"$selected_font_colour"}"
  echo "$fileContent" > "$installDir/theme.txt"

  #Install background
  if [[ "$background" != "" ]]; then
    if [[ ! -f "$background" ]]; then
      if [[ -d "backgrounds/$resolution" ]]; then
        background="backgrounds/$resolution/$background"
      else
        output "error" "Couldn't find \"backgrounds/$resolution/$background\", please report this issue, including a full log of the program's output"
        exit 1
      fi
    fi
    cp "$background" "$installDir/background.png"
  else
    #Set the resolution to generate an image for
    if [[ "$resolution" == "1080p" ]]; then
      customBackgroundRes="1920x1080"
    elif [[ "$resolution" == "4k" ]]; then
      customBackgroundRes="3840x2160"
    elif [[ "$resolution" == "2k" ]]; then
      customBackgroundRes="2560x1440"
    else
      customBackgroundRes="$resolution"
    fi
    output "success" "Generating custom background..."
    convert -size "$customBackgroundRes" -depth 24 "xc:$backgroundColour" "PNG8:$installDir/background.png"
  fi
}

installTheme() {
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
  cp "$installDir/background.png" "$splashScreenPath"

  #Modify grub config
  output "success" "Modifiying grub config..."
  cp -n "/etc/default/grub" "/etc/default/grub.bak"

  updateConfigVal() { #$1: search string, $2: replace string, $3: boolean to append replace string
    #Replace $1 with $2
    if grep "$1" /etc/default/grub >/dev/null 2>&1; then
      sed -i "s|.*$1.*|$2|" /etc/default/grub
    else
      #Append $2 if $3 is true and $1 is missing
      if [[ "$3" == "true" ]]; then
        echo "$2" >> /etc/default/grub
      fi
    fi
  }

  updateConfigVal "GRUB_THEME=" "GRUB_THEME=\"$installDir/theme.txt\"" "true"
  updateConfigVal "GRUB_GFXMODE=" "$gfxmode" "true"
  updateConfigVal "GRUB_TERMINAL=console" "#GRUB_TERMINAL=console"
  updateConfigVal "GRUB_TERMINAL_OUTPUT=console" "#GRUB_TERMINAL_OUTPUT=console"

  #Update grub config
  updateGrub
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

  #Backup existing grub config
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

validArgList=("-h" "--help" "-i" "--install" "-u" "--uninstall" "-e" "--boot" "-p" "--preview" "-b" "--background" "-c" "--custom" "--custom-background" "-r" "--resolution" "-fc" "--fontcolour" "--font-colour" "-fs" "--fontsize" "--font-size" "-f" "--font" "-l" "--bold" "-hl" "--helplabel" "--help-label" "-g" "--generate" "--auto")
read -ra args <<< "${@}"; i=0
while [[ $i -le "$(($# - 1))" ]]; do
  arg="${args[$i]}"
  case $arg in
    -h|--help) output "normal" "Usage: ./install.sh [-OPTION]";
      output "normal" "Help:"
      output "normal" "-h | --help       : Display this page"
      output "normal" "-i | --install    : Install the theme (root)"
      output "normal" "-u | --uninstall  : Uninstall the theme (root)"
      output "normal" "-e | --boot       : Install the theme into '/boot/grub/themes'"
      output "normal" "-p | --preview    : Preview the theme (Works with other options, non-root)"
      output "normal" "-b | --background : Specify which background to use (file)"
      output "normal" "                   - Leave blank to view available backgrounds"
      output "normal" "-c | --custom     : Use a solid colour as a background"
      output "normal" "                   - HTML colour value, must be quoted (\"#FFFFFF\")"
      output "normal" "-r | --resolution : Use a specific resolution (Default: 1080p)"
      output "normal" "                  - Leave blank to view available resolutions"
      output "normal" "-f | --font       : Specify which font to use (file)"
      output "normal" "                   - Leave blank to view available fonts"
      output "normal" "-fc| --fontcolour : Use a specific font colour"
      output "normal" "                   - HTML (must be quoted) and SVG 1.0 colours supported"
      output "normal" "                   - Use the format: -fc \"textcolour,selectedcolour\""
      output "normal" "-fs| --fontsize   : Use a specific font size"
      output "normal" "-l | --bold       : Force font to be bold"
      output "normal" "-hl| --help-label : Add a help label to the bottom of the theme"
      output "normal" "\nRequired arguments: [--install + --background / --uninstall / --preview]"
      output "success" "Program written by: Stuart Hayhurst"; exit 0;;
    -i|--install) programOperation="install";;
    -u|--uninstall) programOperation="uninstall";;
    -e|--boot) installDir="$bootPath/themes/argon";;
    -p|--preview) programOperation="preview";;
    -b|--background) getBackground "${args["$((i + 1))"]}" && i="$((i + 1))";;
    -c|--custom|--custom-background) getCustomBackground "${args["$((i + 1))"]}" && i="$((i + 1))";;
    -r|--resolution) getResolution "${args["$((i + 1))"]}" && i="$((i + 1))";;
    -fc|--fontcolour|--font-colour) getFontColour "${args["$((i + 1))"]}" && i="$((i + 1))";;
    -fs|--fontsize|--font-size) getFontSize "${args["$((i + 1))"]}" && i="$((i + 1))";;
    -f|--font) getFontFile "${args["$((i + 1))"]}" && i="$((i + 1))";;
    -l|--bold) forceBoldFont="true";;
    -hl|--helplabel|--help-label) helpLabel="true";;
    -g|--generate) generateIcons "${args["$((i + 1))"]}" "${args["$((i + 2))"]}" "${args["$((i + 3))"]}" "${args["$((i + 4))"]}"; exit;;
    --auto) auto="true";;
    *) output "error" "Unknown parameter passed: $arg"; exit 1;;
  esac
  i=$((i + 1))
done

warnArgs() {
  if [[ "$resolution" == "" ]]; then
    argWarnings+="$(output "warning" "No resolution specified, using default of 1080p\n")"
    resolution="1080p"
    gfxmode="GRUB_GFXMODE=1920x1080,auto"
  fi
  if [[ "$font_colour" == "" ]]; then
    argWarnings+="$(output "minor" "No font colour specified, use -fc [VALUE] to set a font colour\n")"
    font_colour="#cccccc"
    selected_font_colour="#ffffff"
  fi
  if [[ "$fontsize" == "" ]]; then
    argWarnings+="$(output "warning" "No font size specified, use -fs [VALUE] to set a font size\n")"
    argWarnings+="$(output "warning" "  - Default of 24 will be used\n")"
    fontsize="24"
  fi
  if [[ "$fontfile" == "" ]]; then
    argWarnings+="$(output "warning" "No font specified, use -f [FONTFILE] to set a font, using Terminus Bold\n")"
    forceBoldFont="true"
    fontfile="Terminus.ttf"
  fi
  if [[ "$background" == "" ]] && [[ "$backgroundColour" == "" ]]; then
    argWarnings+="$(output "error" "No background or colour specified, use -b to list available backgrounds\n")"
    argWarnings+="$(output "warning" "  - Call the program with '-b [background]'\n")"
    argsFailed="true"
  fi
  if [[ "$background" != "" ]] && [[ ! -f "$background" ]]; then
    if [[ ! -d "backgrounds/$resolution" ]]; then
      argWarnings+="$(output "error" "The default background can't be used with a custom resolution, other than \"custom\"\n")"
      argsFailed="true"
    fi
  fi
  if [[ "$background" != "" ]] && [[ "$backgroundColour" != "" ]]; then
    argWarnings+="$(output "error" "Use either a background or a colour, not both\n")"
    argsFailed="true"
  fi
  if [[ "$backgroundColour" != "" ]] && [[ "$resolution" == "custom" ]]; then
    argWarnings+="$(output "error" "To use a custom colour background, a resolution must be used, other than \"custom\"\n")"
    argsFailed="true"
  fi
  if [[ "$backgroundColour" != "" ]] && ! checkCommand convert; then
    argWarnings+="$(output "error" "Imagemagick / convert is required to use a custom background colour\n")"
    argsFailed="true"
  fi

  if [[ "$argWarnings" != "" ]]; then
    echo ""; echo "$argWarnings"
    if [[ "$argsFailed" == "true" ]]; then
      exit 1
    fi
  fi
}

if [[ "$programOperation" == "install" ]] || [[ "$programOperation" == "preview" ]]; then
  #Check all required arguments are present and set default values
  warnArgs

  output "success" "Using the following settings:"
  output "list" "Resolution: ${resolution^}"
  if [[ "$background" != "" ]]; then
    output "list" "Background: ${background^}"
  else
    output "list" "Background: ${backgroundColour}"
  fi
  output "list" "Font colour: ${font_colour^}"
  output "list" "Selected font colour: ${selected_font_colour^}"
  output "list" "Font size: $fontsize"
  output "list" "Font file: $fontfile"
  forceBoldFont="${forceBoldFont:-false}"; output "list" "Force bold: ${forceBoldFont^}"

  if [[ "$auto" != "true" ]]; then
    echo ""; output "normal" "Press enter to continue..."; read -r
  fi
fi

if [[ "$programOperation" == "install" ]]; then
  installTheme
elif [[ "$programOperation" == "uninstall" ]]; then
  uninstallTheme
elif [[ "$programOperation" == "preview" ]]; then
  previewTheme
else
  output "error" "One of '--install', '--uninstall' or '--preview' is required"
  exit 1
fi
