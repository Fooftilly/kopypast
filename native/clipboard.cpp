// SPDX-License-Identifier: GPL-3.0-or-later
#include "clipboard.h"

#include <QClipboard>
#include <QGuiApplication>
#include <QThread>

bool Clipboard::copyText(const QString &text) const
{
    // A QGuiApplication owns the clipboard. Do not access it from a
    // non-GUI process or a worker thread.
    auto *application = qobject_cast<QGuiApplication *>(QCoreApplication::instance());
    if (!application || application->thread() != QThread::currentThread())
        return false;
    auto *clipboard = QGuiApplication::clipboard();
    if (!clipboard)
        return false;
    clipboard->setText(text, QClipboard::Clipboard);
    return true;
}
