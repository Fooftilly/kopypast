// SPDX-License-Identifier: GPL-3.0-or-later
#include "clipboard.h"

#include <QClipboard>
#include <QElapsedTimer>
#include <QEvent>
#include <QGuiApplication>
#include <QMimeData>
#include <QTimer>
#include <QWindow>

#include <cstdio>
#include <memory>

namespace {
void marker(const char *value)
{
    std::puts(value);
    std::fflush(stdout);
}

class PeerWindow : public QWindow
{
public:
    bool clicked = false;
protected:
    bool event(QEvent *event) override
    {
        if (event->type() == QEvent::MouseButtonRelease)
            clicked = true;
        return QWindow::event(event);
    }
};
}

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    if (app.arguments().size() != 3)
        return 2;
    const auto role = app.arguments().at(1);
    const auto kind = app.arguments().at(2);
    if ((role != QStringLiteral("writer") && role != QStringLiteral("reader"))
            || (kind != QStringLiteral("text") && kind != QStringLiteral("empty")))
        return 2;
    const bool writer = role == QStringLiteral("writer");
    const auto expected = kind == QStringLiteral("empty") ? QString()
        : QStringLiteral("    Kopypast native clipboard\n<b>literal</b>\tčćž 日本語 😀\n\n");
    const bool wayland = QGuiApplication::platformName().startsWith(QStringLiteral("wayland"));
    PeerWindow window;
    window.resize(640, 480);
    if (wayland)
        window.showFullScreen();
    else
        window.show();

    bool waiting = false;
    bool started = false;
    QElapsedTimer readTime;
    QTimer timer;
    timer.setInterval(50);
    QObject::connect(&timer, &QTimer::timeout, &app, [&] {
        if (!started) {
            if (!window.isExposed() || (wayland && window.width() < 1000))
                return;
            if (wayland) {
                if (!waiting) {
                    marker(writer ? "KOPYPAST_NATIVE_WRITER_WAITING" : "KOPYPAST_NATIVE_READER_WAITING");
                    waiting = true;
                }
                if (!window.clicked || !window.isActive())
                    return;
            }
            started = true;
            if (writer) {
                // Set a nonempty sentinel first; copying an empty string
                // must not leave the previous value available.
                QGuiApplication::clipboard()->setText(QStringLiteral("previous clipboard contents"));
                {
                    Clipboard candidate;
                    if (!candidate.copyText(expected)) {
                        app.exit(3);
                        return;
                    }
                }
                marker("KOPYPAST_NATIVE_WRITER_READY");
                timer.stop();
                return;
            }
            marker("KOPYPAST_NATIVE_READER_READY");
            readTime.start();
        }

        const auto *clipboard = QGuiApplication::clipboard();
        const auto *mime = clipboard->mimeData(QClipboard::Clipboard);
        // Require an actual text offer, including for empty text. An absent
        // selection is not evidence that the writer transferred empty text.
        if (mime && mime->hasText() && clipboard->text(QClipboard::Clipboard) == expected) {
            marker("KOPYPAST_NATIVE_TRANSFER_OK");
            app.quit();
        } else if (readTime.elapsed() > 10000) {
            std::fprintf(stderr, "Clipboard did not transfer expected %s value\n", kind.toUtf8().constData());
            app.exit(4);
        }
    });
    timer.start();
    QTimer::singleShot(65000, &app, [&] { app.exit(5); });
    return app.exec();
}
