<img src="package/contents/icons/io.github.fooftilly.kopypast.svg" width="128" align="left" alt="Kopypast icon"/>

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

To migrate from the original widget, use **Snippets → Backup** there, then **Snippets → Restore** in this fork. Both widgets can coexist. For subsequent updates to this fork, use `--upgrade`.

## Keyboard shortcuts

For a panel instance, right-click Kopypast, open **Configure Kopypast → Keyboard Shortcuts**, and assign a shortcut. Plasma registers the shortcut for that widget instance and handles conflicts. No default key combination is reserved.

The shortcut toggles the popup. With the search bar enabled, opening the popup focuses search when snippets are available. Enable **General → Keyboard navigation** to select results with Up/Down and copy with Enter. The panel icon can also be focused with Tab and activated with Space or Enter.

If several instances are installed, assign a different shortcut to each instance. Test from another application to confirm that Plasma grants focus to the popup.

## Template fields

Use `{ISO_DATE}` or other built-in date/time variables to insert the current value. Use a named field such as `{{PROJECT}}` or `{{PR_NUMBER}}` to ask for text before copying. Each distinct uppercase field appears once, even if used several times in a snippet. The preview uses one date/time snapshot; the copied text is the accepted preview. Values are not saved in the snippet. Cancel to leave the clipboard unchanged.

Prefix a recognized variable or field with a backslash (for example, `\\{{PROJECT}}`) to copy it literally. Disable variable handling in General settings to copy templates unchanged.

## Contributing

Pull requests are welcome. See the [translation guide](translate/README.md) and [KDE Community Code of Conduct](https://kde.org/code-of-conduct).

## License

[GPL-3.0](COPYING).
