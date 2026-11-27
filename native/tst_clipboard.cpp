// SPDX-License-Identifier: GPL-3.0-or-later
#include "clipboard.h"

#include <QClipboard>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QtTest>

class ClipboardTest : public QObject
{
    Q_OBJECT
private slots:
    void copy_data()
    {
        QTest::addColumn<QString>("text");
        QTest::newRow("empty") << QStringLiteral("");
        QTest::newRow("plain") << QStringLiteral("plain text");
        QTest::newRow("unicode") << QStringLiteral("čćž 日本語 😀");
        QTest::newRow("whitespace") << QStringLiteral("  line one\n\tline two\n\n");
        QTest::newRow("literal") << QStringLiteral("<b>literal</b> & {YEAR} {{FIELD}}");
    }

    void copy()
    {
        QFETCH(QString, text);
        QGuiApplication::clipboard()->setText(QStringLiteral("previous clipboard contents"));
        {
            Clipboard candidate;
            QVERIFY(candidate.copyText(text));
        }
        QCOMPARE(QGuiApplication::clipboard()->text(), text);
    }

    void qmlImport()
    {
        QQmlEngine engine;
        engine.addImportPath(QString::fromUtf8(qgetenv("KOPYPAST_TEST_QML_PATH")));
        QQmlComponent component(&engine);
        component.setData("import io.github.fooftilly.kopypast.fileio 1.0\nClipboard {}", QUrl());
        QScopedPointer<QObject> object(component.create());
        QVERIFY2(object, qPrintable(component.errorString()));
        const auto candidate = qobject_cast<Clipboard *>(object.data());
        QVERIFY(candidate);
        QVERIFY(candidate->copyText(QStringLiteral("QML candidate")));
        QCOMPARE(QGuiApplication::clipboard()->text(), QStringLiteral("QML candidate"));
    }
};

QTEST_MAIN(ClipboardTest)
#include "tst_clipboard.moc"
