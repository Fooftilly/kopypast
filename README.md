<img src="package/contents/icons/io.github.vmkspv.kopypast.svg" width="128" align="left" alt="Kopypast icon"/>

# Kopypast

A native KDE Plasma 6 widget for storing, searching and copying reusable text snippets. Keep commands, prompts, templates and other frequently used text close at hand in your panel or on your desktop.

This is a continuation of [Vladimir Kosolapov's original Kopypast project](https://github.com/vmkspv/kopypast), which was archived in October 2026. Development continues in this fork.

<img src="preview.png" width="748" alt="Kopypast popup widget"/>

## Features

- Named, multiline text snippets with title and content search.
- Quick copy to the system clipboard and optional keyboard navigation.
- Manual ordering and usage-based sorting.
- Date and time variables, default templates and configurable popup behavior.
- JSON backup and restoration through the widget settings.
- Local storage in Plasma configuration. No online account is required.

## Requirements

- KDE Plasma 6 with Qt 6 and Kirigami.
- KPackage Manager (`kpackagetool6`).

The upstream project documented support for Plasma 6.5. Compatibility with newer Plasma versions and Wayland is a maintenance priority; current-version runtime testing is pending.

## Installation from source

```sh
git clone https://github.com/Fooftilly/kopypast.git
cd kopypast
kpackagetool6 -t Plasma/Applet --install package
```

Open the Plasma widget browser and add Kopypast to a panel or the desktop.

If you already have Kopypast installed, first export your snippets using **Configure > Snippets > Backup** and save the JSON in a safe location. This fork currently retains the original widget ID, so it is an in-place replacement, not a separate widget. To update an existing installation from the source checkout, use:

```sh
kpackagetool6 -t Plasma/Applet --upgrade package
```

## Usage

1. Open the widget settings and select **Snippets**.
2. Select **Add Snippet**, enter a title and text, and save the settings.
3. Open the widget, find the snippet and select it to copy the text.
4. Paste it in the target application using its normal paste command.

Use **General** in the settings to configure appearance, sorting, variable processing and keyboard navigation. Use **Backup** and **Restore** in the Snippets settings to transfer or recover snippets.

## Development

The applet uses QML and JavaScript, with no separate compiled application or backend. The first maintenance goals are reliable snippet storage and restoration, compatibility with current Plasma releases, and regression tests. New features should preserve existing data and keep the widget lightweight.

Report bugs and propose changes in the [fork's issue tracker](https://github.com/Fooftilly/kopypast/issues). Include your Plasma version, distribution, session type (Wayland or X11), and steps to reproduce the problem. Do not include sensitive snippets in reports.

Contributions are welcome via pull requests. Keep changes focused and test the affected behavior in a Plasma session. See the [translation guide](translate/README.md) for localization.

This project follows the [KDE Community Code of Conduct](https://kde.org/code-of-conduct).

## License

Kopypast is licensed under the [GNU General Public License, version 3](COPYING). Existing source files retain their original copyright and SPDX notices. Thanks to Vladimir Kosolapov and the original contributors.
