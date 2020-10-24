## argon-grub-theme
 - Modern theme for the grub bootloader, containing backgrounds, icons, fonts and styling
 - This theme is based off of [grub2-themes](https://github.com/vinceliuice/grub2-themes)
 - The modifications became a little too heavy for a fork, but commits are upstreamed where possible
 - Wallpaper source files can be found [here](https://github.com/Dragon8oy/argon-wallpapers)

## Installation:

Usage:  `sudo ./install.sh [OPTIONS...]`

|  Options:           | Description: |
|:--------------------|:-------------|
| -h, --help          | Show a help page |
| -i, --install       | Install the grub theme |
| -u, --uninstall     | Uninstall the grub theme |
| -e, --boot          | Install the grub theme into `/boot/grub/themes` instead |
| -b, --background    | Use a custom background image (must be a .png) |
| -r, --resolution    | Select the display resolution |
| -g, --generate      | Generate the theme's assets |
| -c, --compress      | Compress the theme's assets losslessly |
| --clean             | Delete all the theme's assets |
Required arguments: [--install + --background / --uninstall / --generate / --compress / --clean]

### Examples:
 - Install the theme for a 4k display, using the `Night` wallpaper:
   - `sudo ./install.sh --install --resolution 4k --background Night`

 - Install the theme into /boot/grub/themes:
   - `sudo ./install.sh -i -e -b Night`

 - Uninstall the theme:
   - `sudo ./install.sh -u`

### Using a custom background:

 - Find the resolution of your display, and make sure your background matches the resolution
 - Place your custom background inside the root of the project
 - Run the installer like normal, but with `--background [filename.png]` and `-- resolution [YOUR_RESOLUTION]`
   - Resolutions: (1920x1080 -> --1080p, 2560x1080 -> --ultrawide, 2560x1440 -> --2k, 3840x2160 -> --4k)
   - Make sure to replace `[YOUR_RESOLUTION]` with your resolution and `[THEME]` with the theme

## Contributing:
 - If you made changes to any images, or added a new one:
   - Run `./install.sh --clean`
   - Run `./install.sh --generate`
   - Run `./install.sh --compress`
 - Create a pull request from your branch or fork
 - If any issues occur, report then to the [issue](https://github.com/Dragon8oy/argon-grub-theme/issues) page
 - Thank you :)
