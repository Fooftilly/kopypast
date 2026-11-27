<img src="package/contents/icons/io.github.vmkspv.kopypast.svg" width="128" align="left" alt="Kopypast icon"/>

# Kopypast

A KDE Plasma 6 widget for storing, searching and copying text snippets.

Maintained fork of [Vladimir Kosolapov's Kopypast](https://github.com/vmkspv/kopypast).

<img src="preview.png" width="748" alt="Popup widget"/>

## Installation

Requires KDE Plasma 6 and `kpackagetool6`.

```sh
git clone https://github.com/Fooftilly/kopypast.git
cd kopypast
kpackagetool6 -t Plasma/Applet --install package
```

Add Kopypast using the Plasma widget browser.

For existing installations, back up your snippets in the widget settings first. Use `--upgrade` instead of `--install`. The widget ID is unchanged.

## Contributing

Pull requests are welcome. See the [translation guide](translate/README.md) and [KDE Community Code of Conduct](https://kde.org/code-of-conduct).

## License

[GPL-3.0](COPYING).
